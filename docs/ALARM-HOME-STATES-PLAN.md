# Alarm completion and Home states

**Status:** Implemented after Gate 1 approval; commit and PR authorized by the user.

The refined visual contract and current verification live in
[Alarm cards and challenge consistency](ALARM-PROGRESS-DESIGN.md). That document
supersedes the original yellow-card layout and contrast measurements.

## Approved behavior

- Successful real challenges return Home after alarm stop, resource cleanup and
  journal recording. Practice retains its manual completion flow.
- A green check identifies the correct alarm completed today. Repeating alarms
  retain their next ring. Practice, self-confirmation and dismissed attempts do
  not create a completion check.
- Enabled cards retain Edit / Try / Delete in the footer and show challenge name,
  mode and next date. Routine scheduling-success copy is removed.
- Disabled alarms collapse to a muted time/Off row with a switch and delete.
  Tapping the time still opens the editor. Genuine schedule warnings remain.
- Optional journal alarm identity, mode and challenge snapshots preserve legacy
  decoding. Old entries are never assigned guessed alarm or challenge details.
- Failed persistence retains the existing progress-save warning. Home refreshes
  date-dependent completion through the platform minute timeline.

## Baseline verification

The first implementation passed 61 SwiftPM tests, the portable suite with 98.29%
line coverage, 39 native tests and seven focused UI tests. The visual revision
adds immutable mode/challenge metadata and day selection to Progress; see the
current design document for its focused results and remaining limits.

The user's request to open a PR supplies Gate 2 authorization.
