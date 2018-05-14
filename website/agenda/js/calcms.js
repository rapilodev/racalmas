var calcms = (function($) {
	// define this
	var my = {};

	// calcms base functions
	// event handlers are customized at herbstradio.org

	my.updateContainer = function updateContainer(id, url, onLoading, callback) {
		if (id == null)
			return;
		if ($("#" + id).length == 0)
			return;
		// if (onLoading)document.getElementById(id).innerHTML="lade ...";
		$("#" + id).load(url, null, callback);
	}

	my.load = function load(url) {
		window.location.href = url;
		// $(window).load(url);
		// $('html').load(url);
	}

	my.postContainer = function postContainer(url, parameters, callback) {
		if (url != '')
			$.post(url, parameters, callback);
	}

	// get calcms setting
	my.get = function get(name) {
		if (calcms_settings[name] == null)
			return '';
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
		if ($(id) && $(id).length > 0)
			$(id)[0].selectedIndex = 0;
	}

	my.contains = function contains(s, t) {
		if (s == false)
			return false;
		if (t == false)
			return false;
		return s.indexOf(t) != -1;
	}

	my.getJsName = function getJsName(s) {
		s = s.replace(/[^a-zA-Z\_0-9]/g, '_');
		s = s.replace(/_+/g, '_');
		return s;
	}

	my.isArchive = function isArchive() {
		if ($('#calcms_archive:checked').length == 0)
			return 0;
		return 1;
	}

	my.getSearchElement = function getSearchElement() {
		return $("#calcms_search input[name='search']");
	}

	my.resetSearch = function resetSearch() {
		$("#calcms_search_field").val('');
	}

	// set calcms_settings to parameters from URL
	my.evaluateParametersFromUrl = function evaluateParametersFromUrl() {
		var location = new String(window.location);

		if (!location.match(my.get("base_url")))
			return;

		if (window.location.search != "") {
			var parameters = window.location.search.split("?")[1].split("&");
			for (var i = 0; i < parameters.length; i++) {
				var pair = parameters[i];
				var name_values = pair.split("=");
				if (name_values != null) {
					// alert(name_values[0]+"="+name_values[1]);
					// set(name_values[0],name_values[1]);
					var element = document.getElementById(name_values[0]);
					if (element != null)
						element.value = name_values[1];
				}
			}
		}

		var sendung = /\/sendung\/(\d+)\//;
		sendung.exec(location);

		if (RegExp.$1 != null && RegExp.$1 != '') {
			// alert(RegExp.$1);
			set('event_id', RegExp.$1);
			set('last_event_id', my.get('event_id'));
		} else {

			var sendungen = /\/sendungen\/(\d{4}\-\d{2}\-\d{2})\/(\d{4}\-\d{2}\-\d{2})\/(\d)\//;
			sendungen.exec(location);
			if (RegExp.$1 != '' && RegExp.$2 != '' && RegExp.$3 != '') {
				set('from_date', RegExp.$1);
				set('till_date', RegExp.$2);
				set('weekday', RegExp.$3);
			} else {

				var sendungen = /\/sendungen\/(\d{4}\-\d{2}\-\d{2})\/(\d{4}\-\d{2}\-\d{2})\//;
				sendungen.exec(location);
				if (RegExp.$1 != '' && RegExp.$2 != '') {
					set('from_date', RegExp.$1);
					set('till_date', RegExp.$2);
				} else {
					var sendungen = /\/sendungen\/(\d{4}\-\d{2}\-\d{2})\//;
					sendungen.exec(location);
					if (RegExp.$1 != '') {
						set('date', RegExp.$1);
					}
				}

			}

			var kalender = /\/kalender\/(\d{4}\-\d{2}\-\d{2})\/(\d{4}\-\d{2}\-\d{2})\//;
			kalender.exec(location);
			if (RegExp.$1 != '' && RegExp.$2 != '') {
				set('from_date', RegExp.$1);
				set('till_date', RegExp.$2);
			} else {
				var kalender = /\/kalender\/(\d{4}\-\d{2}\-\d{2})\//;
				kalender.exec(location);
				if (RegExp.$1 != '') {
					set('date', RegExp.$1);
				}
			}
		}
	}

	// return URL from calcms_settings
	// parameters can be overwritten by field and value
	// This handles main controller interaction logics
	my.setAndGetUrlParameters = function setAndGetUrlParameters(field, value) {

		// overwrite fields by field and value
		if (field != null && value != null && field != '') {
			// alert(target+" "+field+" "+value);
			set(field, value);
		}

		// read fields
		var debug = my.get('debug');
		var from_date = my.get('from_date');
		var till_date = my.get('till_date');
		var date = my.get('date');
		var month = my.get('month');
		var weekday = my.get('weekday');
		var time_of_day = '';
		var time = '';
		var program = my.get('program');
		var series_name = my.get('series_name');
		var category = my.get('category');
		var tag = my.get('tag');
		var search_field = my.get('search');

		// delete filters by current action
		if ((field == 'search' && search_field != '')
				|| (field == 'category' && category != '')
				|| (field == 'series_name' && series_name != '')
				|| (field == 'program' && program != '') || (field == 'tag')
				&& tag != '') {
			weekday = '';
			date = '';
			from_date = '';
			till_date = '';
		}

		if (field == 'search') {
			category = '';
			series_name = '';
			program = '';
		}

		if (field == 'category') {
			search_field = '';
			series_name = '';
			program = '';
		}

		if (field == 'program') {
			search_field = '';
			series_name = '';
			category = '';
		}

		if (field == 'series_name') {
			search_field = '';
			program = '';
			category = '';
		}

		if (field == 'month') {
			if (month != '') {
				from_date = month;
				till_date = month.substring(0, month.length - 2) + "31";
			}
			weekday = '';
			date = '';
			category = '';
			program = '';
			series_name = '';
			tags = '';
			search_field = '';
		}

		if (field == 'week') {
			weekday = '';
			date = '';
			category = '';
			program = '';
			series_name = '';
			tags = '';
			search_field = '';
		}

		if (field == 'weekday') {
			/*
			 * if (month != ''){ from_date=month;
			 * till_date=month.substring(0,month.length-2)+"31" ; }
			 */
			category = '';
			program = '';
			series_name = '';
			tags = '';
			search_field = '';
		}

		if (field == 'date') {
			weekday = '';
			from_date = '';
			till_date = '';
			category = '';
			program = '';
			series_name = '';
			tags = '';
			search_field = '';
		}

		if (field == 'time') {
			if (time == 'null') {
				return

				

								

				

			} else {
				weekday = '';
				time_of_day = '';
			}
		}

		if (field == 'month' || field == 'week' || field == 'weekday'
				|| field == 'time_of_day') {
			time = '';
		}

		// build target URL
		var url = '';

		if (field == 'month' || field == 'week') {
			if (from_date != '')
				url += '/' + from_date;
			if (till_date != '')
				url += '/' + till_date;
		} else if (weekday != '') {
			if (from_date != '')
				url += '/' + from_date;
			if (till_date != '')
				url += '/' + till_date;
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

		if (category != null && category != '') {
			url += "/kategorie/" + category;
		}

		if (series_name != null && series_name != '') {
			url += "/sendereihe/" + series_name;
		}

		if (url.substr(url.length - 1, url.length) != '/') {
			url += '/';
		}

		if (time_of_day != '') {
			url += "&time_of_day=" + time_of_day;
		} else if (time != '' && time != 'null') {
			url += "&" + time;
		}

		if (tag != null && tag != '') {
			url += "&tag=" + tag;
		}

		if (program != null && program != '') {
			url += "&program=" + program;
		}

		if (field == 'print') {
			url += "&print=1";
		}

		if (debug != '') {
			url += '&debug=' + debug;
		}

		return url;
	}

	// show current project categories
	my.showProjectCategories = function showProjectCategories(project) {
		var projectJsName = calcms.getJsName(project);
		$('#calcmsCategoryForm select').each(function() {
			var id = $(this).attr('id');
			if (id == "calcms_category_" + projectJsName) {
				if ($(this).css('display') == 'none')
					$(this).show();
			} else {
				if ($(this).css('display') != 'none')
					$(this).hide();
			}
		});
	}

	// show current series categories
	my.showProjectSeriesNames = function showProjectSeriesNames(project) {
		var projectJsName = calcms.getJsName(project);
		$('#calcmsSeriesNamesForm select').each(function() {
			var id = $(this).attr('id');
			if (id == "calcms_series_name_" + projectJsName) {
				if ($(this).css('display') == 'none')
					$(this).show();
			} else {
				if ($(this).css('display') != 'none')
					$(this).hide();
			}
		});
	}

	// get current project
	my.getProject = function getProject() {
		var project = $('#calcms_project');
		if (project.length == 0)
			return 'all';
		return project.val();
	}

	// remove projects from form without categories and series_names
	my.removeEmptyProjects = function removeEmptyProjects() {
		$('#calcms_project option').each(
				function() {
					var project = $(this).val();
					var hasCategories = $('#calcms_category_'
							+ calcms.getJsName(project)).length;
					var hasSeries = $('#calcms_series_name_'
							+ calcms.getJsName(project)).length;
					if ((hasCategories == 0) && (hasSeries == 0)) {
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
			if (value != '' && value != null)
				url += escape(value) + '/';
			if (archive != null && archive == 0)
				url += 'kommende/';
			if (archive != null && archive == 1)
				url += 'vergangene/';
			my.updateContainer('calcms_list', url, 1);
		}
	}

	// show all events for a given category
	my.showEventsByCategory = function showEventsByCategory(value) {
		if (value != '' && value != null) {
			my.updateContainer('calcms_list', my.get('search_category_url')
					+ escape(value) + '/', 1);
		}
	}

	// show all events for a given project and category
	my.showEventsByProjectAndCategory = function showEventsByProjectAndCategory(
			project, category, archive) {
		if (category != '' && category != null) {
			var url = my.get('search_category_url');
			if (project != '' && project != null)
				url += escape(project) + '/';
			if (category != '' && category != null)
				url += escape(category) + '/';
			if (archive != null && archive == 0)
				url += 'kommende/';
			if (archive != null && archive == 1)
				url += 'vergangene/';
			my.updateContainer('calcms_list', url, 1);
		}
	}

	// show all events for a given project and series
	my.showEventsByProjectAndSeriesName = function showEventsByProjectAndSeriesName(
			project, seriesName, archive) {
		if (seriesName != '' && seriesName != null) {
			var url = my.get('search_series_name_url');
			if (project != '' && project != null)
				url += escape(project) + '/';
			if (seriesName != '' && seriesName != null)
				url += escape(seriesName) + '/';
			if (archive != null && archive == 0)
				url += 'kommende/';
			if (archive != null && archive == 1)
				url += 'vergangene/';
			my.updateContainer('calcms_list', url, 1);
		}
	}

	// show all events for a given series
	my.showEventsBySeriesName = function showEventsBySeriesName(value) {
		if (value != '' && value != null) {
			my.updateContainer('calcms_list', my.get('search_series_name_url')
					+ escape(value) + '/', 1);
		}
	}

	// show all events for a given program
	my.showEventsByProgram = function showEventsByProgram(value) {
		var events_url = my.get('events_url');
		var url = my.setAndGetUrlParameters('program', value);
		if (value != '' && value != null) {
			// my.updateContainer('calcms_list', events_url+url, 1);
			my.updateContainer('calcms_list', url, 1);
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
			my.updateContainer('calcms_menu', menu_url + url, 1);

			if (event_id != '' && event_id != null && Number(event_id) != 'NaN') {
				// load list selected by url
				my.showEvents(event_id, '');
				my.set('event_id', '');
			} else {
				// load event list
				my.updateContainer('calcms_list', events_url + url, 1);
				my.set('last_list_url', events_url + url);
			}

		}
		return false;
	}

	// load given event details into list
	my.showEvents = function showEvents(event_id, view) {
		if (view == null || view == '')
			view = 'list_url';
		if (event_id != '') {
			var url = my.get(view) + '/' + event_id + '/';
			my.updateContainer('calcms_list', url, 1);
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
							1,
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
		// my.set('date',date);
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
	// (current day)
	my.showTodaysCalendarAndEvents = function showTodaysCalendarAndEvents(month) {
		my.set('month', month);
		// my.set(date,'today');
		my.showMenuAndList('', 'date', 'today');
		my.showCalendar('', 'month');
		return false;

	};

	// update menu, list and calendar widget by entries of given month YYYY-MM
	my.showCalendarAndEventsByMonth = function showCalendarAndEventsByMonth(
			month) {
		my.set('month', month);
		my.showMenuAndList('', 'month');
		my.showCalendar('', 'month');
		return false;

	};

	// update menu, list and calendar widget by entries of given date YYYY-MM-DD
	my.showCalendarAndEventsByDate = function showCalendarAndEventsByDate(date) {
		my.set('date', date);
		my.showMenuAndList('', 'date');

		my.set('month', date);
		my.showCalendar('', 'month');
		return false;

	};

	// end of Calendar actions

	// show comment for given event id and start time
	my.showCommentsByEventIdOrEventStart = function showCommentsByEventIdOrEventStart(
			event_id, event_start) {
		var url = my.get('comments_url') || '/agenda/kommentare/';
		if (event_id == '' || event_start == '' || url == '')
			return false;
		console.log("showCommentsByEventIdOrEventStart url="+url);

		my.set('comments_event_start', event_start);
		my.set('comments_event_id', event_id);

		url += event_id + '/' + event_start + '/';

		my.updateContainer('calcms_comments', url);
	}

	// add a comment to a event
	my.addComment = function addComment(id, comment) {
		var url = my.get('add_comment_url');
		if (url != '')
			$.post(url, $("#" + id).serialize(), function(data) {
				my.showCommentsByEventIdOrEventStart(my
						.get('comments_event_id'), my
						.get('comments_event_start'));

			});
		return false;
	}

	// insert new comment form
	my.showCommentForm = function showCommentForm(id, parent_id, event_id,
			event_start) {
		var response = '<div>';
		if (parent_id != '') response += 'Deine Anwort:';
		var html = response
		html += '<form id="add_comment_' + parent_id +'"'
		html += ' action="/agenda/kommentar_neu/?" method="post"'
		html += ' onsubmit="calcms.addComment(\'add_comment_'+parent_id+'\',this);return false;"'
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
		html += '<input name="event_id"    value="' + event_id + '" type="hidden" />'
		html += '<input name="parent_id"    value="' + parent_id + '" type="hidden" />'
		html += '<input name="event_start" value="' + event_start + '" type="hidden" />'
        html += '</form>'
        html += '</div>';

        document.getElementById(id).innerHTML = html

		my.show(id);
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
		;
		return false;
	}

	// init search interface: load search form content if not loaded yet
	my.initSearch = function initSearch(target, field) {
		if (my.get('preloaded') == '') {
			var category_url = my.get('category_url');
			var program_url = my.get('program_url');
			var series_name_url = my.get('series_name_url');
			var debug = my.get('debug');

			if (category_url != null && category_url != '')
				my.updateContainer('calcms_categories', category_url, 1);
			if (program_url != null && program_url != '')
				my.updateContainer('calcms_programs', program_url, 1);
			if (series_name_url != null && series_name_url != '')
				my.updateContainer('calcms_series_names', series_name_url, 1);
		}
		return false;
	}

	// wrapper to show an id
	my.show = function show(id) {
		$("#" + id).show("drop");
		document.getElementById(id).style.visibility = "visible";
		// document.getElementById(id).style.display="block";
	}

	// wrapper to hide an id
	my.hide = function hide(id) {
		$("#" + id).hide("drop");
		document.getElementById(id).style.visibility = "hidden";
		// document.getElementById(id).style.display="none";
	}

	// return max date
	my.setDateIfBefore = function setDateIfBefore(date1, date2) {
		if (date1 < date2)
			return date2;
		return date1;
	}

	// return min date
	my.setDateIfAfter = function setDateIfAfter(date1, date2) {
		if (date1 > date2)
			return date2;
		return date1;
	}

	// remove Drupal header for currently playing entry at topic overview page
	my.removeCurrentPlayingHeader = function removeCurrentPlayingHeader() {
		$("h2 a[href$='/testing']").each(function() {
			$(this).css("display", "none");
		});
	}

	// return instance
	return my;
}(jQuery));

