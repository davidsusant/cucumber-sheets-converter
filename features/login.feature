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