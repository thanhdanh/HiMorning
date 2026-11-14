SHELL := /bin/sh

IOS_PROJECT := apps/ios/HiMorning.xcodeproj
IOS_BUILD := $(CURDIR)/.build
IOS_ARTIFACTS := $(IOS_BUILD)/artifacts
IOS_XCODE := perl -e 'alarm shift; exec @ARGV' 900 xcodebuild -project "$(IOS_PROJECT)" -scheme HiMorning -derivedDataPath "$(IOS_BUILD)/DerivedData"
IOS_DEVICE_APP := $(IOS_BUILD)/DerivedData/Build/Products/Release-iphoneos/HiMorning.app
VERSION ?= 1.0
BUILD_NUMBER ?= 1

.PHONY: doctor ios-project ios-core-test ios-release-check ios-sim-ready ios-uitest ios-shot ios-devices ios-device ios-archive ios-testflight

doctor:
	@xcodebuild -version && xcodegen --version && xcrun --sdk iphoneos --show-sdk-version
	@security find-identity -v -p codesigning | sed -E 's/[[:xdigit:]]{40}/<fingerprint>/g'
	@mkdir -p "$(IOS_ARTIFACTS)"
	@xcrun simctl list devices available >"$(IOS_ARTIFACTS)/simulators.log" 2>&1 && cat "$(IOS_ARTIFACTS)/simulators.log" || { tail -4 "$(IOS_ARTIFACTS)/simulators.log"; exit 1; }

ios-project:
	@mkdir -p "$(IOS_ARTIFACTS)"
	xcodegen generate --spec apps/ios/project.yml

ios-core-test:
	sh scripts/test-swift.sh

ios-release-check: ios-project
	@$(IOS_XCODE) -configuration Release -destination 'generic/platform=iOS' \
		CODE_SIGNING_ALLOWED=NO MARKETING_VERSION="$(VERSION)" CURRENT_PROJECT_VERSION="$(BUILD_NUMBER)" build \
		>"$(IOS_ARTIFACTS)/ios-release-check.log" 2>&1 || { tail -45 "$(IOS_ARTIFACTS)/ios-release-check.log"; exit 1; }
	@tail -3 "$(IOS_ARTIFACTS)/ios-release-check.log"

ios-sim-ready:
	@test -n "$(IOS_SIM)" || { echo 'Pass an available iPhone simulator UDID as IOS_SIM.'; exit 64; }
	@mkdir -p "$(IOS_ARTIFACTS)"
	@perl -e 'alarm shift; exec @ARGV' 180 xcrun simctl bootstatus "$(IOS_SIM)" -b \
		>"$(IOS_ARTIFACTS)/simulator-boot.log" 2>&1 || { tail -20 "$(IOS_ARTIFACTS)/simulator-boot.log"; exit 1; }

ios-uitest: ios-project ios-sim-ready
	@run_dir=$$(mktemp -d "$(IOS_ARTIFACTS)/ui.XXXXXX"); \
		RUNNER_WORKSPACE="$(IOS_BUILD)" RUNNER_TEMP="$$run_dir" \
		perl -e 'alarm shift; exec @ARGV' 1200 sh scripts/test-ios.sh "$(IOS_SIM)" push "$(ONLY)" >"$$run_dir/test.log" 2>&1; \
		result=$$?; echo "Test evidence: $$run_dir"; tail -30 "$$run_dir/test.log"; exit $$result

ios-shot:
	@test -d "$(IOS_RESULT)" && test -n "$(ONLY)" || { echo 'Pass IOS_RESULT and the UI test identifier as ONLY.'; exit 64; }
	@mkdir -p "$(IOS_ARTIFACTS)/shots"
	@shot_dir=$$(mktemp -d "$(IOS_ARTIFACTS)/shots/run.XXXXXX") && \
		xcrun xcresulttool export attachments --path "$(IOS_RESULT)" --test-id "$(ONLY)" \
		--filter '*.png' --output-path "$$shot_dir"

ios-devices:
	@xcrun devicectl list devices --timeout 30

ios-device: ios-project
	@test -n "$(DEVICE_ID)" && test -n "$(TEAM_ID)" || { echo 'Pass DEVICE_ID and TEAM_ID for a connected iPhone.'; exit 64; }
	@$(IOS_XCODE) -configuration Release -destination 'platform=iOS,id=$(DEVICE_ID)' \
		CODE_SIGN_STYLE=Automatic CODE_SIGNING_ALLOWED=YES CODE_SIGNING_REQUIRED=YES \
		CODE_SIGN_IDENTITY='Apple Development' DEVELOPMENT_TEAM="$(TEAM_ID)" \
		MARKETING_VERSION="$(VERSION)" CURRENT_PROJECT_VERSION="$(BUILD_NUMBER)" build \
		>"$(IOS_ARTIFACTS)/ios-device-build.log" 2>&1 || { tail -35 "$(IOS_ARTIFACTS)/ios-device-build.log"; exit 1; }
	@tail -3 "$(IOS_ARTIFACTS)/ios-device-build.log"
	@codesign --verify --strict "$(IOS_DEVICE_APP)"
	@xcrun devicectl device install app --device "$(DEVICE_ID)" --timeout 120 "$(IOS_DEVICE_APP)"
	@xcrun devicectl device process launch --device "$(DEVICE_ID)" --timeout 30 \
		--activate --terminate-existing com.himorning.HiMorning

ios-archive: ios-project
	@test -n "$(TEAM_ID)" || { echo 'Pass the enrolled Apple Developer team as TEAM_ID.'; exit 64; }
	@test ! -e "$(IOS_ARTIFACTS)/HiMorning-$(VERSION)-$(BUILD_NUMBER).xcarchive" || { echo 'Archive already exists. Choose an unused BUILD_NUMBER.'; exit 64; }
	@$(IOS_XCODE) -configuration Release -destination 'generic/platform=iOS' \
		-archivePath "$(IOS_ARTIFACTS)/HiMorning-$(VERSION)-$(BUILD_NUMBER).xcarchive" \
		-allowProvisioningUpdates CODE_SIGN_STYLE=Automatic CODE_SIGNING_ALLOWED=YES \
		DEVELOPMENT_TEAM="$(TEAM_ID)" MARKETING_VERSION="$(VERSION)" CURRENT_PROJECT_VERSION="$(BUILD_NUMBER)" archive \
		>"$(IOS_ARTIFACTS)/ios-archive.log" 2>&1 || { tail -45 "$(IOS_ARTIFACTS)/ios-archive.log"; exit 1; }
	@tail -3 "$(IOS_ARTIFACTS)/ios-archive.log"

ios-testflight:
	@test -d "$(TESTFLIGHT_ARCHIVE)/Products/Applications/HiMorning.app" || { echo 'Pass the verified HiMorning archive as TESTFLIGHT_ARCHIVE.'; exit 64; }
	@mkdir -p "$(IOS_ARTIFACTS)"
	@run_dir=$$(mktemp -d "$(IOS_ARTIFACTS)/testflight.XXXXXX") && \
		printf '%s\n' '{"method":"app-store-connect","destination":"upload","signingStyle":"automatic","testFlightInternalTestingOnly":true,"manageAppVersionAndBuildNumber":false}' \
		| plutil -convert xml1 -o "$$run_dir/ExportOptions.plist" -- - && \
		{ echo "Upload evidence: $$run_dir"; \
			perl -e 'alarm shift; exec @ARGV' 1800 xcodebuild -exportArchive \
				-archivePath "$(TESTFLIGHT_ARCHIVE)" -exportPath "$$run_dir/export" \
				-exportOptionsPlist "$$run_dir/ExportOptions.plist" -allowProvisioningUpdates \
				>"$$run_dir/upload.log" 2>&1; \
			result=$$?; tail -25 "$$run_dir/upload.log"; exit $$result; }
