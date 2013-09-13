Feature: Show book details

In order to help the users know more about the book they are holding in
their hands, the users should see information about the book when
placing it on the shelf

Scenario: Put book on shelf

    Given the book has an RFID-tag
    And the book is placed on the shelf
    Then I should see the title and author of the book
