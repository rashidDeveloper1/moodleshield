<?php
// Post-install hook for mod_readinglibrary.
// Moodle's XMLDB engine creates all tables from db/install.xml automatically.
// This file runs once after the schema is created and seeds any required defaults.

defined('MOODLE_INTERNAL') || die();

function xmldb_readinglibrary_install(): bool {
    // No default data required at install time.
    // Table structure is fully defined in db/install.xml.
    return true;
}
