<?php
namespace mod_readinglibrary;

defined('MOODLE_INTERNAL') || die();

/**
 * Manages the full borrow lifecycle for a single book.
 *
 * Responsibilities:
 *   - Check copy availability before lending
 *   - Issue a single-use session token for secure PDF delivery
 *   - Record returns and free the copy for the next borrower
 */
class borrow_manager {

    private const BORROW_DAYS = 14;

    public function __construct(private readonly \moodle_database $db) {}

    /**
     * Borrow a book for the given user.
     * Throws \moodle_exception when no copies are available.
     *
     * @return string One-time session token used to stream the PDF.
     */
    public function borrow(int $book_id, int $user_id): string {
        if (!$this->has_available_copy($book_id)) {
            throw new \moodle_exception('nocopiesavailable', 'mod_readinglibrary');
        }

        $token = $this->generate_token();

        $this->db->insert_record('readinglibrary_borrow', (object) [
            'bookid'        => $book_id,
            'userid'        => $user_id,
            'borrowed_at'   => time(),
            'due_at'        => time() + (self::BORROW_DAYS * DAYSECS),
            'returned_at'   => null,
            'session_token' => $token,
        ]);

        return $token;
    }

    /**
     * Mark a borrow record as returned, invalidating its session token.
     */
    public function return_book(int $borrow_id, int $user_id): void {
        $record = $this->db->get_record(
            'readinglibrary_borrow',
            ['id' => $borrow_id, 'userid' => $user_id],
            '*',
            MUST_EXIST
        );

        if ($record->returned_at !== null) {
            throw new \moodle_exception('alreadyreturned', 'mod_readinglibrary');
        }

        $this->db->set_field(
            'readinglibrary_borrow',
            'returned_at',
            time(),
            ['id' => $borrow_id]
        );
    }

    /**
     * Validate a session token and return the book file path.
     * Invalidates the token after one successful use.
     */
    public function redeem_token(string $token): string {
        $borrow = $this->db->get_record(
            'readinglibrary_borrow',
            ['session_token' => $token],
            '*',
            MUST_EXIST
        );

        if ($borrow->returned_at !== null || time() > $borrow->due_at) {
            throw new \moodle_exception('tokenexpired', 'mod_readinglibrary');
        }

        $book = $this->db->get_record(
            'readinglibrary_book',
            ['id' => $borrow->bookid],
            'filepath',
            MUST_EXIST
        );

        // Rotate token so the same link cannot be replayed
        $this->db->set_field(
            'readinglibrary_borrow',
            'session_token',
            $this->generate_token(),
            ['id' => $borrow->id]
        );

        return $book->filepath;
    }


    private function has_available_copy(int $book_id): bool {
        $book = $this->db->get_record('readinglibrary_book', ['id' => $book_id], 'total_copies', MUST_EXIST);
        $active = $this->db->count_records_select(
            'readinglibrary_borrow',
            'bookid = :bookid AND returned_at IS NULL',
            ['bookid' => $book_id]
        );
        return $active < $book->total_copies;
    }

    private function generate_token(): string {
        return bin2hex(random_bytes(32));
    }
}
