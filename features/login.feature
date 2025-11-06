@platform:web
@team:authentication
@story:user-login
Feature: User Login

  Background:
    Given user is on login page

  @automated
  @positive
  @severity:critical
  @smoke @regression @sanity
  Scenario: User can login with valid email and password
    When user enters valid email "user@example.com"
    And user enters valid password
    And user clicks login button
    Then user should be redirected to dashboard
    And user should see welcome message

  @automated
  @negative
  @severity:critical
  @smoke @regression
  Scenario: User cannot login with invalid email
    When user enters invalid email "invalid@example.com"
    And user enters valid password
    And user clicks login button
    Then user should see error message "Invalid email or password"
    And user should remain on login page

  @automated
  @negative
  @severity:critical
  @regression
  Scenario: User cannot login with invalid password
    When user enters valid email "user@example.com"
    And user enters invalid password
    And user clicks login button
    Then user should see error message "Invalid email or password"
    And user should remain on login page

  @automated
  @negative
  @severity:high
  @regression
  Scenario: User cannot login with empty email
    When user leaves email field empty
    And user enters valid password
    And user clicks login button
    Then user should see validation error "Email is required"