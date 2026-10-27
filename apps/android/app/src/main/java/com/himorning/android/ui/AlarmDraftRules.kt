package com.himorning.android.ui

import com.himorning.android.core.Alarm

/** A scoped edit cannot accidentally overwrite fields that its screen does not expose. */
internal fun mergeAlarmEdits(original: Alarm, edited: Alarm, scope: AlarmEditorScope): Alarm = when (scope) {
    AlarmEditorScope.ALL -> edited.copy(id = original.id)
    AlarmEditorScope.SCHEDULE -> original.copy(hour = edited.hour, minute = edited.minute, weekdays = edited.weekdays, label = edited.label)
    AlarmEditorScope.CHALLENGE -> original.copy(mode = edited.mode, challenge = edited.challenge, repetitions = edited.repetitions, seated = edited.seated)
}
