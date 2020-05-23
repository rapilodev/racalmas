var calcms = (function($) {
    // define this
    var my = {};

    // calcms base functions
    my.updateContainer = function updateContainer(id, url, callback) {
        if (id == null) return;
        var elem = document.querySelector('#' + id);
        if (elem == null) return;
        fetch( url )
            .then( response => response.text())
            .then( text => {
                elem.innerHTML = text;
                if (callback != null) callback();
            })
            .catch( error => { 
                console.error('Error:', error);
            });
    }

    my.load = function load(url) {
        window.location.href = url;
    }

    my.show = function (elem) {
	    elem.style.display = 'block';
    };

    my.hide = function (elem) {
	    elem.style.display = 'none';
    };

    my.toggle = function (elem) {
	    if (window.getComputedStyle(elem).display === 'block') {
		    my.hide(elem);
	    }else{
    	    my.show(elem);
        }
    };

    // get calcms setting
    my.get = function get(name) {
        if (calcms_settings[name] == null) return '';
        return calcms_settings[name];
    }

    // set calcms setting
    my.set = function set(name, value) {
        calcms_settings[name] = value;
    }

    // get select box value
    my.selectValue = function selectValue(element) {
        value = element.options[element.selectedIndex].value;
        return value;
    }

    my.selectFirstOption = function selectFirstOption(id) {
        if ($(id) && $(id).length > 0) $(id)[0].selectedIndex = 0;
    }

    my.contains = function contains(s, t) {
        if (s == false) return false;
        if (t == false) return false;
        return s.indexOf(t) != -1;
    }

    my.getJsName = function getJsName(s) {
        s = s.replace(/[^a-zA-Z\_0-9]/g, '_');
        s = s.replace(/_+/g, '_');
        return s;
    }

    my.isArchive = function isArchive() {
        if ($('#calcms_archive:checked').length == 0) return 0;
        return 1;
    }

    my.getSearchElement = function getSearchElement() {
        return $("#calcms_search input[name='search']");
    }

    my.resetSearch = function resetSearch() {
        $("#calcms_search_field").val('');
    }

    // return URL from calcms_settings
    // parameters can be overwritten by field and value
    // This handles main controller interaction logics
    my.setAndGetUrlParameters = function setAndGetUrlParameters(field, value) {

        // overwrite fields by field and value
        if (field != null && value != null && field != '') set(field, value);

        // read fields
        var debug = my.get('debug');
        var from_date = my.get('from_date');
        var till_date = my.get('till_date');
        var date = my.get('date');
        var month = my.get('month');
        var weekday = my.get('weekday');
        var time = '';
        var series_name = my.get('series_name');
        var search_field = my.get('search');

        // delete filters by current action
        if ((field == 'search' && search_field != '')
                || (field == 'series_name' && series_name != '')) {
            weekday = '';
            date = '';
            from_date = '';
            till_date = '';
        }

        if (field == 'search') {
            series_name = '';
            program = '';
        }

        if (field == 'series_name') {
            search_field = '';
            program = '';
        }

        if (field == 'month') {
            if (month != '') {
                from_date = month;
                till_date = month.substring(0, month.length - 2) + "31";
            }
            weekday = '';
            date = '';
            series_name = '';
            search_field = '';
        }

        if (field == 'week') {
            weekday = '';
            date = '';
            series_name = '';
            search_field = '';
        }

        if (field == 'weekday') {
            series_name = '';
            search_field = '';
        }

        if (field == 'date') {
            weekday = '';
            from_date = '';
            till_date = '';
            series_name = '';
            search_field = '';
        }

        if (field == 'time') {
            if (time == 'null') {
                return;
            } else {
                weekday = '';
            }
        }

        if (field == 'month' || field == 'week' || field == 'weekday') {
            time = '';
        }

        // build target URL
        var url = '';

        if (field == 'month' || field == 'week') {
            if (from_date != '') url += '/' + from_date;
            if (till_date != '') url += '/' + till_date;
        } else if (weekday != '') {
            if (from_date != '') url += '/' + from_date;
            if (till_date != '') url += '/' + till_date;
            url += '/' + weekday;
        } else if (date != '') {
            if (date == 'today') {
                url += '/heute/';
            } else {
                url += '/' + date;
            }
        }

        if (search_field != '') {
            url += "/suche/" + search_field;
        }

        if (series_name != null && series_name != '') {
            url += "/sendereihe/" + series_name;
        }

        if (url.substr(url.length - 1, url.length) != '/') {
            url += '/';
        }

        if (field == 'print') {
            url += "&print=1";
        }

        if (debug != '') {
            url += '&debug=' + debug;
        }

        return url;
    }

    // show current series
    my.showProjectSeriesNames = function showProjectSeriesNames(project) {
        var projectJsName = calcms.getJsName(project);
        $('#calcmsSeriesNamesForm select').each(function() {
            var id = $(this).attr('id');
            if (id == "calcms_series_name_" + projectJsName) {
                if ($(this).css('display') == 'none') $(this).show();
            } else {
                if ($(this).css('display') != 'none') $(this).hide();
            }
        });
    }

    // get current project
    my.getProject = function getProject() {
        var project = $('#calcms_project');
        if (project.length == 0) return 'all';
        return project.val();
    }

    // remove projects from form without series_names
    my.removeEmptyProjects = function removeEmptyProjects() {
        $('#calcms_project option').each(
                function() {
                    var project = $(this).val();
                    var hasSeries = $('#calcms_series_name_'
                            + calcms.getJsName(project)).length;
                    if (hasSeries == 0) {
                        $(this).remove();
                    }
                });
    }

    my.clearOnChangeArchive = function clearOnChangeArchive() {
        $('#calcms_archive').off();
    }

    // register action on changing archive
    my.registerOnChangeArchive = function registerOnChangeArchive(action) {
        my.clearOnChangeArchive();
        $('#calcms_archive').on('click', action);
    }

    // show all events for a given project
    my.showSearchResultsByProject = function showSearchResultsByProject(
            project, value, archive) {
        if (value != null && value != '') {
            var url = my.get('search_url');
            if (project != '' && project != null)
                url += escape(project) + '/';
            else
                url += 'all/';
            if (value != '' && value != null) url += escape(value) + '/';
            if (archive != null && archive == 0) url += 'kommende/';
            if (archive != null && archive == 1) url += 'vergangene/';
            my.updateContainer('calcms_list', url);
        }
    }

    // show all events for a given project and series
    my.showEventsByProjectAndSeriesName = function showEventsByProjectAndSeriesName(
            project, seriesName, archive) {
        if (seriesName != '' && seriesName != null) {
            var url = my.get('search_series_name_url');
            if (project != '' && project != null) url += escape(project) + '/';
            if (seriesName != '' && seriesName != null)
                url += escape(seriesName) + '/';
            if (archive != null && archive == 0) url += 'kommende/';
            if (archive != null && archive == 1) url += 'vergangene/';
            my.updateContainer('calcms_list', url);
        }
    }

    // show all events for a given series
    my.showEventsBySeriesName = function showEventsBySeriesName(value) {
        if (value != '' && value != null) {
            my.updateContainer('calcms_list', my.get('search_series_name_url')
                    + escape(value) + '/');
        }
    }

    // show all events for a given program
    my.showEventsByProgram = function showEventsByProgram(value) {
        var events_url = my.get('events_url');
        var url = my.setAndGetUrlParameters('program', value);
        if (value != '' && value != null) {
            my.updateContainer('calcms_list', url);
        }
    }

    // show next event of a given series
    my.showNextSeriesEvent = function showNextSeriesEvent(value) {
        var events_url = my.get('next_series_url');
        my.load(events_url + '/' + value + '.html');
    }

    // show previous event of a given series
    my.showPrevSeriesEvent = function showPrevSeriesEvent(value) {
        var events_url = my.get('prev_series_url');
        my.load(events_url + '/' + value + '.html');
    }

    my.showMenuAndList = function showMenuAndList(target, field, value) {

        var events_url = my.get('events_url');
        var menu_url = my.get('menu_url');
        var event_id = my.get('event_id');

        var url = my.setAndGetUrlParameters(field, value);

        if (target == 'window') {
            window.location.href = events_url + url;
        } else {
            my.updateContainer('calcms_menu', menu_url + url);

            if (event_id != '' && event_id != null && Number(event_id) != 'NaN') {
                // load list selected by url
                my.showEvents(event_id, '');
                my.set('event_id', '');
            } else {
                // load event list
                my.updateContainer('calcms_list', events_url + url);
                my.set('last_list_url', events_url + url);
            }

        }
        return false;
    }

    // load given event details into list
    my.showEvents = function showEvents(event_id, view) {
        if (view == null || view == '') view = 'list_url';
        if (event_id != '') {
            var url = my.get(view) + '/' + event_id + '/';
            my.updateContainer('calcms_list', url);
        } else {
            document.getElementById('calcms_list').innerHTML = 'keine Sendung gefunden...';
        }
    }

    // load given event details into list
    my.showEvent = function showEvent(event_id) {
        var old_url = my.get('last_list_url');
        var url = my.get('list_url') + '/' + event_id + '/';
        if (url != old_url) {
            my.set('last_event_id', event_id);
            my
                    .updateContainer(
                            'calcms_list',
                            url,
                            function(responseText, textStatus, XMLHttpRequest) {
                                var back_link = '<a href="#" onclick="updateContainer(\'calcms_list\',\''
                                        + old_url
                                        + '\');return false;">zur&uuml;ck</a>';
                                document.getElementById('calcms_list').innerHTML = back_link
                                        + document
                                                .getElementById('calcms_list').innerHTML
                                        + '<p><hr/>' + back_link;
                            });
        }
    }

    // Calendar actions

    // update menu and list by given date
    my.showEventsByDate = function showEventsByDate(date) {
        my.showMenuAndList('', 'date', date);
        return false;

    };

    // update menu and list by events from weekday at given date range
    my.showEventsByWeekday = function showEventsByWeekday(from, till, weekday) {
        my.set('from_date', from);
        my.set('till_date', till);
        my.set('weekday', weekday);
        my.showMenuAndList('', 'weekday');
        return false;

    };

    // update menu and list by events from given date range
    my.showEventsByDateRange = function showEventsByDateRange(from, till) {
        my.set('from_date', from);
        my.set('till_date', till);
        my.showMenuAndList('', 'week');
        return false;
    };

    // load calendar content
    my.showCalendar = function showCalendar(target, field) {
        var calendar_debug = my.get('calendar_debug');
        var calendar_url = my.get('calendar_url');
        var debug = my.get('debug');
        var date = my.get('month');

        var url = calendar_url;

        if (field == 'month') {
            url += '/' + date + '/';
        }
        if (debug != '') {
            url += '&debug=' + debug;
        }

        if (target == 'window') {
            window.location.href = events_url + url;
        } else {
            my.updateContainer('calcms_calendar', url);
        }

        if (calendar_debug != null) {
            calendar_debug.innerHTML = url;
        }
        return false;
    }

    // update menu, list and calendar widget by entries of given month YYYY-MM
    my.showCalendarAndEventsByMonth = function showCalendarAndEventsByMonth(
            month) {
        my.set('month', month);
        my.showMenuAndList('', 'month');
        my.showCalendar('', 'month');
        return false;

    };

    // end of Calendar actions

    // show comment for given event id and start time
    my.showCommentsByEventIdOrEventStart = function showCommentsByEventIdOrEventStart(
            event_id, event_start) {
        var url = my.get('comments_url') || '/agenda/kommentare/';
        if (event_id == '' || event_start == '' || url == '') return false;
        console.log("showCommentsByEventIdOrEventStart url=" + url);

        my.set('comments_event_start', event_start);
        my.set('comments_event_id', event_id);

        url += event_id + '/' + event_start + '/';

        my.updateContainer('calcms_comments', url);
    }

    // add a comment to a event
    my.addComment = function addComment(id, comment) {
        var url = my.get('add_comment_url');
        if (url == '') return;

        var formElement = document.getElementById(id);
        const data = new URLSearchParams();
        for (const pair of new FormData(formElement)) {
            data.append(pair[0], pair[1]);
        }
        fetch( url, {
            method: 'post',
            body: data
        })
        .then( response => response.text() )
        .then( result => {
            console.log('Success:', result);
            my.showCommentsByEventIdOrEventStart(
                my.get('comments_event_id'), 
                my.get('comments_event_start')
            );        
        })
        .catch( error => { 
            console.error('Error:', error);
        });

        return false;
    }

    // insert new comment form
    my.showCommentForm = function showCommentForm(id, parent_id, event_id,
            event_start) {
        var response = '<div>';
        if (parent_id != '') response += 'Deine Anwort:';
        var html = response
        html += '<form id="add_comment_' + parent_id + '"'
        html += ' action="/agenda/kommentar_neu/?" method="post"'
        html += ' onsubmit="calcms.addComment(\'add_comment_' + parent_id
                + '\',this);return false;"'
        html += '>'
        html += 'Mit dem Absenden Ihres Kommentars erklären Sie sich mit der Veröffentlichung der Daten einverstanden.<br> ';
        html += 'Die Email-Addresse ist optional, dient privaten Antworten und wird nicht veröffentlicht.<br> '
        html += 'Details siehe <a href="/datenschutzerklaerung/">Datenschutzerklärung und Widerrufshinweise</a>.<br>'
        html += '<input name="author" maxlength="40" placeholder="Nickname"/><br />'
        html += '<textarea name="content" cols="60" rows="10"'
        html += ' onkeyup="javascript:if (this.value.length>1000) this.value=this.value.substr(0,1000)"'
        html += ' placeholder="Was ich sagen will, ist..."'
        html += ' ></textarea><br />'
        html += '<input name="email" maxlength="40" placeholder="Email-Addresse f&uuml;r R&uuml;ckmeldungen"/><br />'
        html += '<input type="submit" value="absenden!" style="color:#000"/>'
        html += '<input name="event_id"    value="' + event_id
                + '" type="hidden" />'
        html += '<input name="parent_id"    value="' + parent_id
                + '" type="hidden" />'
        html += '<input name="event_start" value="' + event_start
                + '" type="hidden" />'
        html += '</form>'
        html += '</div>';

        document.getElementById(id).innerHTML = html;
        my.show(document.getElementById(id));
        document.getElementById(id).style.visibility = "visible";
    }
    // end of Comment actions

    // used to embed playlist in external pages
    my.showPlaylist = function showPlaylist() {
        var url = my.get('playlist_url');
        my.updateContainer('calcms_playlist', url);
    }

    // load comments into #calcms_newest_comments if not embedded yet
    my.showNewestComments = function showNewestComments() {
        if (my.get('preloaded') == '') {
            var url = my.get('newest_comments_url');
            my.updateContainer('calcms_newest_comments', url);
        }
        return false;
    }

    // export selected events to ical
    my.exportSelectedToICal = function exportSelectedToICal() {
        window.location = my.get('ical_url') + my.setAndGetUrlParameters();
        return false;
    }

    // init search interface: load search form content if not loaded yet
    my.initSearch = function initSearch(target, field) {
        if (my.get('preloaded') == '') {
            var program_url = my.get('program_url');
            var series_name_url = my.get('series_name_url');
            var debug = my.get('debug');

            if (program_url != null && program_url != '')
                my.updateContainer('calcms_programs', program_url);
            if (series_name_url != null && series_name_url != '')
                my.updateContainer('calcms_series_names', series_name_url);
        }
        return false;
    }

    // return instance
    return my;
}(jQuery));
