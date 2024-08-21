### API Description

The API offers a comprehensive suite of endpoints designed to manage and access event-related data. The endpoints cover event listings, details, playlists, comments, feeds, calendar integration, and search functionalities. Below is a detailed overview of the available routes and their functionalities, along with their German localizations.

#### **Event Management**

- **List Events:**
  - **GET /events/today/** - List events for today.
  - **GET /events/{start_date}/{end_date}/{weekday}/{additional_parameters}** - List events between specified dates, optionally filtered by weekday.
  - **GET /events/{start_date}/{end_date}/{additional_parameters}** - List events between specified dates.
  - **GET /events/{date}/{additional_parameters}** - List events for a specific date.
  - **GET /events/{additional_parameters}** - Generic event listing based on additional parameters.

- **Event Details:**
  - **GET /event/{event_id}/...** - Get details for a specific event by its ID.

- **Playlists:**
  - **GET /playlist/{additional_parameters}** - Get a short-term playlist of future events.
  - **GET /playlistLong/{additional_parameters}** - Get a long-term playlist of future events.
  - **GET /playlistUtc/{additional_parameters}** - Get a playlist in UTC format.
  - **GET /playlist_show/{additional_parameters}** - Get a playlist of future events related to a specific show.

- **Running Events:**
  - **GET /running_event/{additional_parameters}** - Get currently running events.
  - **GET /running_event_id/{additional_parameters}** - Get details of currently running events by ID.

#### **Menu Management**

- **Event Menus:**
  - **GET /menu/{start_date}/{end_date}/{weekday}/{additional_parameters}** - Get event menus between dates, optionally filtered by weekday.
  - **GET /menu/{start_date}/{end_date}/{additional_parameters}** - Get event menus between dates.
  - **GET /menu/{date}/{additional_parameters}** - Get event menu for a specific date.
  - **GET /menu/today/{additional_parameters}** - Get event menu for today.

#### **Series Management**

- **Series Information:**
  - **GET /series/{additional_parameters}** - Get series information.
  - **GET /serie/{project}/{series_name}/upcoming/{additional_parameters}** - List upcoming events in a series.
  - **GET /serie/{project}/{series_name}/over/{additional_parameters}** - List past events in a series.
  - **GET /serie/{project}/{series_name}/show/** - Redirect to a specific show in a series.
  - **GET /serie/{project}/{series_name}/{additional_parameters}** - List events in a series.
  - **GET /serie/{series_name}/{additional_parameters}** - List events based on series name.

#### **Calendar Integration**

- **Calendar Events:**
  - **GET /calendar/{date}/** - Get events for a specific date.
  - **GET /calendar/{start_date}/{end_date}/** - Get events between specified dates.
  - **GET /calendar/{additional_parameters}** - Generic calendar event listing based on additional parameters.

#### **Feeds and Export Formats**

- **Feeds:**
  - **GET /feed/{additional_parameters}** - Get Atom feed for future events.
  - **GET /atom/{additional_parameters}** - Alias for Atom feed.
  - **GET /rss/{additional_parameters}** - Get RSS feed for future events.
  - **GET /rss-media/{additional_parameters}** - Get RSS feed for media-related events.

- **iCal Exports:**
  - **GET /ical/{start_date}/{end_date}/{weekday}/{additional_parameters}** - Export events as iCal format between dates, optionally filtered by weekday.
  - **GET /ical/{start_date}/{end_date}/{additional_parameters}** - Export events as iCal format between dates.
  - **GET /ical/{date}/{additional_parameters}** - Export events for a specific date in iCal format.
  - **GET /ical/{event_id}/{additional_parameters}** - Export a specific event in iCal format.
  - **GET /ical/{additional_parameters}** - Generic iCal export based on additional parameters.

#### **Search**

- **Event Search:**
  - **GET /search/{project}/{search_term}/coming/{additional_parameters}** - Search for upcoming events.
  - **GET /search/{project}/{search_term}/over/{additional_parameters}** - Search for past events.
  - **GET /search/{project}/{search_term}/{additional_parameters}** - Generic search for events.

#### **Comments**

- **Comment Management:**
  - **GET /comments/latest/{additional_parameters}** - Fetch latest comments with optional filters.
  - **GET /comments/feed/{additional_parameters}** - Get comments feed in XML format.
  - **POST /comments/add/{additional_parameters}** - Add a new comment.
  - **GET /comments/{event_id}/{start_time}/{additional_parameters}** - Fetch comments for a specific event.

#### **Special Routes**

- **Dashboard and Other Utilities:**
  - **GET /dashboard/event/{event_id}/...** - Get dashboard details for an event.
  - **GET /dashboard/date/{date}/** - Get dashboard data for a specific date.
  - **GET /dashboard/{additional_parameters}** - Generic dashboard information.

- **Miscellaneous:**
  - **GET /freefm.xml** - FreeFM XML feed.
  - **GET /frrapo-programm.html** - FRRAPO program details.
  - **POST /upload_playout_piradio** - Upload play-out data.
  - **GET /redaktionen-{location}** - Fetch series information for specific locations.

---

### German Localizations

- **Event Management:**
  - **GET /sendungen/heute/** - List events for today.
  - **GET /sendungen/{start_date}/{end_date}/{weekday}/{additional_parameters}** - List events between specified dates.
  - **GET /sendungen/{start_date}/{end_date}/{additional_parameters}** - List events between specified dates.
  - **GET /sendungen/{date}/{additional_parameters}** - List events for a specific date.
  - **GET /sendungen/{additional_parameters}** - Generic event listing based on additional parameters.

- **Event Details:**
  - **GET /sendung/{event_id}/...** - Get details for a specific event by its ID.

- **Playlists:**
  - **GET /sendungen/{additional_parameters}** - List short-term playlists of future events.
  - **GET /sendungen/{additional_parameters}** - List long-term playlists of future events.
  - **GET /sendungen/{additional_parameters}** - List playlists in UTC format.
  - **GET /sendungen/{additional_parameters}** - List playlists of future events related to a specific show.

- **Running Events:**
  - **GET /sendungen/{additional_parameters}** - List currently running events.
  - **GET /sendungen/{additional_parameters}** - List details of currently running events by ID.

- **Menu Management:**
  - **GET /menu/{start_date}/{end_date}/{weekday}/{additional_parameters}** - Get event menus between dates.
  - **GET /menu/{start_date}/{end_date}/{additional_parameters}** - Get event menus between dates.
  - **GET /menu/{date}/{additional_parameters}** - Get event menu for a specific date.
  - **GET /menu/heute/{additional_parameters}** - Get event menu for today.

- **Series Management:**
  - **GET /sendereihen/{additional_parameters}** - Get series information.
  - **GET /sendereihe/{project}/{series_name}/kommende/{additional_parameters}** - List upcoming events in a series.
  - **GET /sendereihe/{project}/{series_name}/vergangene/{additional_parameters}** - List past events in a series.
  - **GET /sendereihe/{project}/{series_name}/show/** - Redirect to a specific show in a series.
  - **GET /sendereihe/{project}/{series_name}/{additional_parameters}** - List events in a series.
  - **GET /sendereihe/{series_name}/{additional_parameters}** - List events based on series name.

- **Calendar Integration:**
  - **GET /kalender/{date}/** - Get events for a specific date.
  - **GET /kalender/{start_date}/{end_date}/** - Get events between specified dates.
  - **GET /kalender/{additional_parameters}** - Generic calendar event listing based on additional parameters.

- **Feeds and Export Formats:**
  - **GET /feed_kommentare/{additional_parameters}** - Get Atom feed for comments.
  - **GET /atom/{additional_parameters}** - Alias for Atom feed.
  - **GET /rss/{additional_parameters}** - Get RSS feed for future events.
  - **GET /rss-media/{additional_parameters}** - Get RSS feed for media-related events.

- **iCal Exports:**
  - **GET /ical/{start_date}/{end_date}/{weekday}/{additional_parameters}** - Export events as iCal format between dates.
  - **GET /ical/{start_date}/{end_date}/{additional_parameters}** - Export events as iCal format between dates.
  - **GET /ical/{date}/{additional_parameters}** - Export events for a specific date in iCal format.
  - **GET /ical/{event_id}/{additional_parameters}** - Export a specific event in iCal format.
 
