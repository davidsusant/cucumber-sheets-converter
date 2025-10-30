@platform:web
@team:authentication
@story:user-registration
Feature: User Registration

  Background:
    Given user is on registration page

  @automated
  @positive
  @severity:critical
  @smoke @regression @sanity
  Scenario: User can register with valid information
    When user enters valid email "newuser@example.com"
    And user enter valid password "SecurePass123!"
    And user confirms password "SecurePass123!"
    And user enters full name "John Doe"
    And user accepts terms and conditions
    And user clicks register button
    Then user should receive confirmation email
    And user should see success message "Registration successful"

  @automated
  @negative
  @severity:high
  @regression
  Scenario: User cannot register with existing email
    When user enters email "existing@example.com"
    And user enters valid password
    And user confirms password
    And user enters full name
    And user accepts terms and conditions
    And user clicks register button
    Then user should see error message "Email already registered"