<?php
// Standard Moodle module API callbacks required for every activity plugin.

defined('MOODLE_INTERNAL') || die();

/**
 * Add a new Reading Library instance to a course.
 * Called by Moodle when a teacher saves the activity form.
 */
function readinglibrary_add_instance(stdClass $data): int {
    global $DB;
    $data->timecreated  = time();
    $data->timemodified = time();
    return $DB->insert_record('readinglibrary', $data);
}

/**
 * Update an existing Reading Library instance.
 */
function readinglibrary_update_instance(stdClass $data): bool {
    global $DB;
    $data->id           = $data->instance;
    $data->timemodified = time();
    return $DB->update_record('readinglibrary', $data);
}

/**
 * Delete a Reading Library instance and all associated books and borrows.
 * Cascading FK constraints in the DB handle child rows automatically.
 */
function readinglibrary_delete_instance(int $id): bool {
    global $DB;
    return $DB->delete_records('readinglibrary', ['id' => $id]);
}

/**
 * Return feature support flags consumed by Moodle core.
 */
function readinglibrary_supports(int $feature): ?bool {
    return match ($feature) {
        FEATURE_MOD_INTRO          => true,
        FEATURE_BACKUP_MOODLE2     => true,
        FEATURE_COMPLETION_TRACKS_VIEWS => true,
        default                    => null,
    };
}
