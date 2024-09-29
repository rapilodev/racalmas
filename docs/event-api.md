Certainly! The `check_params` function processes and validates a wide range of parameters that can be used in queries, likely for fetching or displaying events. Below is a detailed description of each parameter, including the possible values and their purpose:

### Query Parameters

1. **`running_at`**
   - **Description**: Specifies a particular datetime for which an event query should be run.
   - **Possible Values**:
     - Any valid datetime string (e.g., `2024-09-04T10:00:00`).
   - **Notes**: When set, this parameter overrides other time-related parameters and returns the next event after this datetime.

2. **`time`**
   - **Description**: Specifies the time of day for events.
   - **Possible Values**:
     - Any valid time string (e.g., `14:00`).
   - **Notes**: Used to filter events occurring at a specific time.

3. **`from_time`**
   - **Description**: Sets the start time for filtering events.
   - **Possible Values**:
     - Any valid time string (e.g., `09:00`).
   - **Notes**: Combined with `till_time` to define a time range.

4. **`till_time`**
   - **Description**: Sets the end time for filtering events.
   - **Possible Values**:
     - Any valid time string (e.g., `18:00`).
   - **Notes**: Used in conjunction with `from_time` to define a time range.

5. **`date`**
   - **Description**: Specifies a single date for querying events.
   - **Possible Values**:
     - Any valid date string (e.g., `2024-09-04`).
   - **Notes**: Used when both `from_date` and `till_date` are not specified.

6. **`from_date`**
   - **Description**: Defines the start date for querying events.
   - **Possible Values**:
     - Any valid date string (e.g., `2024-09-01`).
   - **Notes**: Combined with `till_date` to filter events within a date range.

7. **`till_date`**
   - **Description**: Defines the end date for querying events.
   - **Possible Values**:
     - Any valid date string (e.g., `2024-09-30`).
   - **Notes**: Used with `from_date` to define a date range.

8. **`date_range_include`**
   - **Description**: Indicates whether to include or exclude the end date in the range.
   - **Possible Values**:
     - `1`: Exclude the end date.
     - `0`: Include the end date.
   - **Default**: `0` (Include the end date).

9. **`order`**
   - **Description**: Specifies the order of the results.
   - **Possible Values**:
     - `asc`: Ascending order.
     - `desc`: Descending order.

10. **`weekday`**
    - **Description**: Filters events by a specific day of the week.
    - **Possible Values**:
      - `1` to `7`: Corresponding to Monday through Sunday.
    - **Notes**: If set, only events occurring on the specified weekday will be returned.

11. **`tag`**
    - **Description**: Filters events by a specific tag.
    - **Possible Values**:
      - Any string without spaces or semicolons.
    - **Notes**: Useful for categorizing and searching events by tags.

12. **`series_name`**
    - **Description**: Filters events by the name of a series.
    - **Possible Values**:
      - Any string, trimmed of leading and trailing spaces.
    - **Notes**: Can be used to retrieve events belonging to a specific series.

13. **`title`**
    - **Description**: Filters events by their title.
    - **Possible Values**:
      - Any string, trimmed of leading and trailing spaces.
    - **Notes**: Only events with titles matching the given string will be returned.

14. **`location`**
    - **Description**: Filters events by their location.
    - **Possible Values**:
      - Any string, trimmed of leading and trailing spaces.
    - **Notes**: Can be used to limit results to a specific location.

15. **`exclude_locations`**
    - **Description**: Excludes events from specific locations.
    - **Possible Values**:
      - `1`: Exclude specified locations.
      - `0`: Include all locations.
    - **Default**: `0` (Include all locations).

16. **`exclude_projects`**
    - **Description**: Excludes events from specific projects.
    - **Possible Values**:
      - `1`: Exclude specified projects.
      - `0`: Include all projects.
    - **Default**: `0` (Include all projects).

17. **`exclude_event_images`**
    - **Description**: Excludes events with images.
    - **Possible Values**:
      - `1`: Exclude events with images.
      - `0`: Include all events.
    - **Default**: `0` (Include all events).

18. **`phase`**
    - **Description**: Filters events by their phase or status.
    - **Possible Values**:
      - `future`: Only future events.
      - `ongoing`: Currently ongoing events.
      - `past`: Completed or past events.
      - `all`: All events, regardless of phase.

19. **`last_days`**
    - **Description**: Limits the results to events from the last X days.
    - **Possible Values**:
      - Any integer value (e.g., `7` for the last 7 days).
    - **Notes**: Useful for retrieving recent events.

20. **`next_days`**
    - **Description**: Limits the results to events in the next X days.
    - **Possible Values**:
      - Any integer value (e.g., `7` for the next 7 days).
    - **Notes**: Useful for retrieving upcoming events.

21. **`event_id`**
    - **Description**: Filters events by a specific event ID.
    - **Possible Values**:
      - Any positive integer.
    - **Notes**: Only the event with the matching ID will be returned.

22. **`excerpt`**
    - **Description**: Specifies the level of detail to return in the event data.
    - **Possible Values**:
      - `none`: No excerpt.
      - `summary`: A brief summary of the event.
      - `detailed`: Full details of the event.
    - **Default**: `detailed`.

23. **`description`**
    - **Description**: Specifies the format of the event description.
    - **Possible Values**:
      - `none`: No description.
      - `text`: Plain text description.
      - `html`: HTML formatted description.
    - **Default**: `text`.

24. **`search`**
    - **Description**: A search string to filter events.
    - **Possible Values**:
      - Any string up to 100 characters.
    - **Notes**: Filters events containing the search string in relevant fields.

25. **`template`**
    - **Description**: Specifies the template used for rendering the event data.
    - **Possible Values**:
      - `no`: No template.
      - `html`: HTML template.
      - Other valid template names.
    - **Default**: `event_list.html`.

26. **`limit`**
    - **Description**: Limits the number of events returned.
    - **Possible Values**:
      - Any positive integer.
    - **Default**: Set by configuration, usually 100.

27. **`project`**
    - **Description**: Filters events by project.
    - **Possible Values**:
      - Any valid project name.
    - **Notes**: Retrieves events belonging to the specified project.

28. **`project_name`**
    - **Description**: Filters events by the name of a project.
    - **Possible Values**:
      - Any string.
    - **Notes**: Used to identify and filter events by project name.

29. **`studio_name`**
    - **Description**: Filters events by studio name.
    - **Possible Values**:
      - Any string.
    - **Notes**: Used to identify and filter events by studio name.

30. **`project_id`**
    - **Description**: Filters events by project ID.
    - **Possible Values**:
      - Any positive integer.
    - **Notes**: Used to specify and filter events by a project ID.

31. **`studio_id`**
    - **Description**: Filters events by studio ID.
    - **Possible Values**:
      - Any positive integer.
    - **Notes**: Used to specify and filter events by a studio ID.

32. **`json_callback`**
    - **Description**: A callback function name for JSONP requests.
    - **Possible Values**:
      - Any valid JavaScript function name (alphanumeric and underscores).
    - **Notes**: Useful for cross-domain requests in JSONP format.

33. **`extern`**
    - **Description**: Specifies whether to use external or relative links.
    - **Possible Values**:
      - `1`: Use external links.


 - `0`: Use relative links.
    - **Default**: `0`.

34. **`phase_allows_unscheduled`**
    - **Description**: Indicates whether to include unscheduled events in a phase.
    - **Possible Values**:
      - `1`: Include unscheduled events.
      - `0`: Exclude unscheduled events.
    - **Default**: `1`.

35. **`mode`**
    - **Description**: Specifies the mode of operation or query.
    - **Possible Values**:
      - `ajax`: For AJAX requests.
      - Other modes specific to the application.
    - **Default**: `ajax`.

### Notes:
- **Default Values**: Several parameters have default values, as indicated above, which apply when the parameter is not explicitly set in the query.
- **Combination of Parameters**: Many parameters can be combined to fine-tune the query, such as using `from_date` and `till_date` together to define a date range, or combining `time` and `weekday` to filter events on a specific day and time.
- **Sanitization**: Parameters like `title`, `location`, `series_name`, etc., are sanitized to remove unwanted characters or spaces, ensuring they are in a proper format for querying the database.

This comprehensive list of parameters allows users or developers to create highly specific queries tailored to their needs, ensuring that they can retrieve just the events they are interested in, formatted and sorted according to their preferences.