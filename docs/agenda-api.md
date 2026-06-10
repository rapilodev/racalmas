### API Description

The API provides a suite of endpoints for managing and accessing event-related data, including listings, details, playlists, comments, feeds, calendar integration, and search functionalities. Below is a detailed overview of the available routes and their functionalities.

#### **Event Management**

- **List Events:**
  - **GET /events/today/** - List today's events.
  - **GET /events/{from_date}/{till_date}/{weekday}/...** - List events between specific dates, filtered by weekday.
  - **GET /events/{from_date}/{till_date}/...** - List events between specific dates.
  - **GET /events/{date}/...** - List events for a specific date.
  - **GET /events/rds/...** - Get the latest event in RDS format.
  - **GET /events/json/...** - Get event data in JSON format.
  - **GET /events/...** - General event listing based on parameters.

- **Event Details:**
  - **GET /event/{event_id}/...** - Get details of a specific event by its ID.
  - **GET /event/running/id/...** - Get details of the currently running event by ID.
  - **GET /event/running/...** - Get details of currently running events.
  - **GET /event/...** - General event details based on parameters.

- **Playlists:**
  - **GET /playlist/long/...** - Get a long-term playlist of future events.
  - **GET /playlist/utc/...** - Get the event playlist in UTC format.
  - **GET /playlist/show/...** - Get a playlist of future events related to a specific show.
  - **GET /playlist/...** - Get a short-term playlist of future events.

#### **Menu Management**

- **Event Menus:**
  - **GET /menu/{from_date}/{till_date}/{weekday}/...** - Get event menus between specific dates, filtered by weekday.
  - **GET /menu/{from_date}/{till_date}/...** - Get event menus between specific dates.
  - **GET /menu/{date}/...** - Get the event menu for a specific date.
  - **GET /menu/today/...** - Get today's event menu.
  - **GET /menu/...** - General event menu listing based on parameters.

#### **Series Management**

- **Series Information:**
  - **GET /series/...** - Get series information.
  - **GET /serie/{project}/{series_name}/upcoming/...** - List upcoming events in a series.
  - **GET /serie/{project}/{series_name}/over/...** - List past events in a series.
  - **GET /serie/{project}/{series_name}/show/...** - Redirect to a specific show in a series.
  - **GET /serie/{project}/{series_name}/...** - List events in a series.
  - **GET /serie/{series_name}/...** - List events based on the series name.

#### **Calendar Integration**

- **Calendar Events:**
  - **GET /calendar/{date}/...** - Get events for a specific date.
  - **GET /calendar/{from_date}/{till_date}/...** - Get events between specified dates.
  - **GET /calendar/...** - General calendar event listing based on parameters.

#### **Feeds and Export Formats**

- **Feeds:**
  - **GET /feed/atom/...** - Get Atom feed for future events.
  - **GET /feed/rss/...** - Get RSS feed for future events.
  - **GET /feed/rss-media/...** - Get RSS feed for media-related events.

- **iCal Exports:**
  - **GET /ical/{from_date}/{till_date}/{weekday}/...** - Export events as iCal between specific dates, filtered by weekday.
  - **GET /ical/{from_date}/{till_date}/...** - Export events as iCal between specific dates.
  - **GET /ical/{month}/...** - Export events for a specific month in iCal format.
  - **GET /ical/{date}/...** - Export events for a specific date in iCal format.
  - **GET /ical/{event_id}/...** - Export a specific event in iCal format.
  - **GET /ical/...** - General iCal export based on parameters.

#### **Search**

- **Event Search:**
  - **GET /search/{project}/{search_term}/coming/...** - Search for upcoming events.
  - **GET /search/{project}/{search_term}/over/...** - Search for past events.
  - **GET /search/{project}/{search_term}/...** - General search for events based on project and search term.
  - **GET /search/{search_term}/...** - General search for events based on search term.

#### **Comments**

- **Comment Management:**
  - **GET /comments/latest/...** - Fetch latest comments.
  - **GET /comments/feed/...** - Get comments feed in XML format.
  - **POST /comments/add/...** - Add a new comment.
  - **GET /comments/{event_id}/{event_start}/...** - Fetch comments for a specific event.

#### **Special Routes**

- **Dashboard and Other Utilities:**
  - **GET /dashboard/event/{event_id}/...** - Get dashboard details for a specific event.
  - **GET /dashboard/date/{date}/...** - Get dashboard data for a specific date.
  - **GET /dashboard/date/now/...** - Get current dashboard data.
  - **GET /freefm.xml** - FreeFM XML feed.
  - **GET /frrapo-programm.html** - FRRAPO program details.


### Template Descriptions

#### **1. `event_list.html`**
   - **Purpose:** Displays a list of events.
   - **Usage:** Used for showing events based on a specific date, date range, or filter criteria such as series or search terms.

#### **2. `event_details.html`**
   - **Purpose:** Displays detailed information about a specific event.
   - **Usage:** Used when showing the details of an event identified by its `event_id`.

#### **3. `event_playlist.html`**
   - **Purpose:** Displays a playlist of events.
   - **Usage:** Used to generate a playlist for upcoming events, typically filtered by time or other criteria.

#### **4. `event_playlist_long.html`**
   - **Purpose:** Displays an extended playlist of events.
   - **Usage:** Used to generate a longer playlist, typically with a larger limit on the number of events.

#### **5. `event_playlist_show.html`**
   - **Purpose:** Displays a curated short playlist of events.
   - **Usage:** Used for showing a brief selection of upcoming events.

#### **6. `event_utc_time.json`**
   - **Purpose:** Provides event data in JSON format with UTC time.
   - **Usage:** Used to retrieve event data, particularly focused on timing in UTC.

#### **7. `event_running.html`**
   - **Purpose:** Displays events currently running.
   - **Usage:** Used to show events that are ongoing at the current time.

#### **8. `event_running_id.html`**
   - **Purpose:** Displays the current running event based on its ID.
   - **Usage:** Used to show specific ongoing events, identified by their `event_id`.

#### **9. `event_menu.html`**
   - **Purpose:** Displays a menu of events.
   - **Usage:** Used to generate a menu-style list of events, filtered by date or weekday.

#### **10. `event_redirect.html`**
   - **Purpose:** Redirects to the first upcoming event in a series.
   - **Usage:** Used to automatically redirect to an event page, typically the next upcoming event in a series.

#### **11. `event.atom.xml`**
   - **Purpose:** Provides event data in Atom feed format.
   - **Usage:** Used to generate an Atom feed for upcoming events.

#### **12. `event.rss.xml`**
   - **Purpose:** Provides event data in RSS feed format.
   - **Usage:** Used to generate an RSS feed for upcoming events.

#### **13. `event_media.rss.xml`**
   - **Purpose:** Provides an RSS feed for event media, focusing on recently active recordings.
   - **Usage:** Used to generate an RSS feed of media associated with events from the past week.

#### **14. `event.ics`**
   - **Purpose:** Provides event data in iCalendar format.
   - **Usage:** Used to generate calendar entries for events, typically filtered by date or event ID.

#### **15. `comments_newest.html`**
   - **Purpose:** Displays the newest comments.
   - **Usage:** Used to list the latest comments, usually with a specified limit.

#### **16. `comments.xml`**
   - **Purpose:** Provides comments in XML feed format.
   - **Usage:** Used to generate an XML feed of comments, typically filtered by recent activity.

#### **17. `comments.html`**
   - **Purpose:** Displays comments related to a specific event.
   - **Usage:** Used to show comments for a particular event, sorted by date or other criteria.

#### **18. `event_dashboard_details.html`**
   - **Purpose:** Displays detailed event information in the dashboard.
   - **Usage:** Used in the admin dashboard to show detailed information about a specific event.

#### **19. `event_dashboard.html.js`**
   - **Purpose:** Provides a dashboard interface for events.
   - **Usage:** Used in the admin dashboard to manage and view events based on date or current time.

#### **20. `event_freefm.xml`**
   - **Purpose:** Provides a feed of events for FreeFM.
   - **Usage:** Used to generate an XML feed for FreeFM-related events.

#### **21. `event_frrapo`**
   - **Purpose:** Displays events for the Frrapo program.
   - **Usage:** Used to generate a page for events associated with the Frrapo program.

### CGI Script Parameters

The CGI scripts in the API utilize various parameters to handle different functionalities related to events, playlists, comments, series, calendar integration, and feeds. Below is a detailed explanation of these parameters and their usage.

#### **General Parameters**

- **`date`**: Defines a specific date for querying events or other time-sensitive data.
  - **Format:** `YYYY-MM-DD`
  - **Example:** `date=2024-08-28` retrieves data for August 28, 2024.

- **`from_date`**: Indicates the start date for a range of dates.
  - **Format:** `YYYY-MM-DD`
  - **Example:** `from_date=2024-08-01` starts the query from August 1, 2024.

- **`till_date`**: Specifies the end date for a range of dates.
  - **Format:** `YYYY-MM-DD`
  - **Example:** `till_date=2024-08-31` ends the query on August 31, 2024.

- **`phase`**: Used to specify the time-related filter, often in conjunction with `date`.
  - **Supported values:**
    - `running|now`: Represents the current time.
    - `upcoming|future`: Refers to future events.
    - `completed|past`: Refers to future events.
    - **Example:** `phase=running` fetches events happening right now.

- **`limit`**: Sets the maximum number of results to be returned.
  - **Example:** `limit=10` limits the output to 10 results.

- **`weekday`**: Filters events based on the day of the week.
  - **Format:** A number representing the day of the week (1 for Monday, 7 for Sunday).
  - **Example:** `weekday=1` filters for Monday.

- **`json`**: When set, indicates that the response should be in JSON format.
  - **Example:** `json=1` returns the response in JSON format.

#### **Event-Specific Parameters**

- **`event_id`**: The unique identifier of a specific event.
  - **Example:** `event_id=12345` retrieves the event with ID 12345.

- **`project`**: Used to filter events or series by a specific project name.
  - **Example:** `project=summer_fest` filters events related to "Summer Fest".

- **`series_name`**: Filters events based on the name of a series.
  - **Example:** `series_name=tech_talks` filters events in the "Tech Talks" series.

- **`archive`**: deprecated, see `phase`.
  - **Supported values:**
    - `coming`: Fetch upcoming events.
    - `gone`: Fetch past events.
  - **Example:** `archive=coming` fetches upcoming events.

- **`event_start`**: The start time of an event, often used in comments or details retrieval.
  - **Format:** `YYYY-MM-DDTHH:MM` or `YYYY-MM-DD+HH:MM`
  - **Example:** `event_start=2024-08-28T14:00` represents an event starting at 2:00 PM on August 28, 2024.

- **`search`**: A term used for searching within events or comments.
  - **Example:** `search=music` searches for events related to "music".

- **`sort_order`**: Determines the order of results, typically in ascending (`asc`) or descending (`desc`) order.
  - **Example:** `sort_order=asc` sorts results in ascending order.

#### **Playlist-Specific Parameters**

- **`location`**: Defines the location or context for which the playlist or feed is generated.
  - **Example:** `location=piradio` fetches a playlist for the PiRadio location.

- **`only_active_recording`**: Filters to include only actively recording events.
  - **Supported values:**
    - `1`: Include only active recordings.
  - **Example:** `only_active_recording=1` fetches only currently active recordings.

- **`show_max`**: Limits the number of items shown, especially in comments or playlist.
  - **Example:** `show_max=3` limits the display to 3 items.

#### **Comments Parameters**

- **`type`**: Specifies the type of comments to retrieve.
  - **Example:** `type=list` retrieves comments in a list format.

- **`template`**: Defines the template for the comment output.
  - **Example:** `template=comments.html` renders comments in HTML format.

#### **Calendar Parameters**

- **`date`**: Specific date for which to fetch calendar events.
  - **Example:** `date=2024-08-28` fetches calendar events for August 28, 2024.

- **`from_date`**: Start date for a range of calendar events.
  - **Example:** `from_date=2024-08-01` fetches calendar events starting from August 1, 2024.

- **`till_date`**: End date for a range of calendar events.
  - **Example:** `till_date=2024-08-31` fetches calendar events up to August 31, 2024.

#### **Feed and Export Parameters**

- **`template`**: Specifies the output format, such as Atom, RSS, or iCal.
  - **Example:** `template=event.ics` exports events in iCal format.

- **`last_days`**: Limits results to those from the last specified number of days.
  - **Example:** `last_days=7` includes events from the last 7 days.

#### **Dashboard-Specific Parameters**

- **`event_id`**: ID of the event for dashboard details.
  - **Example:** `event_id=12345` retrieves the dashboard for event ID 12345.

- **`date`**: Specific date for dashboard data.
  - **Example:** `date=2024-08-28` retrieves dashboard data for August 28, 2024.

- **`time`**: Time-related filter for dashboard data.
  - **Example:** `time=now` retrieves current dashboard data.

- **`limit`**: Limits the number of dashboard entries.
  - **Example:** `limit=1` limits the output to a single dashboard entry.
