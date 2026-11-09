<?php
// Plugin identity — Moodle reads this on every upgrade check.

defined('MOODLE_INTERNAL') || die();

$plugin->component = 'mod_readinglibrary';
$plugin->version   = 2025010100;
$plugin->requires  = 2024100700; // Moodle 5.3 minimum
$plugin->maturity  = MATURITY_STABLE;
$plugin->release   = '1.0.0';
