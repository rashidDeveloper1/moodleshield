<?php
// Redirect to the course page — standard pattern for all Moodle activity plugins.

require_once('../../config.php');

$id = required_param('id', PARAM_INT);

$course = $DB->get_record('course', ['id' => $id], '*', MUST_EXIST);

require_course_login($course);

redirect(new moodle_url('/course/view.php', ['id' => $course->id]));
