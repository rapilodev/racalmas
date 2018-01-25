var calcms_settings = new Array();

(function($, calcms) {

	// show current project
	calcms.selectProject = function selectProject() {
		var project = calcms.getProject();
		console.log("project=" + project)

		calcms.clearOnChangeArchive();
		calcms.showProjectCategories(project);
		calcms.showProjectSeriesNames(project);
		calcms.selectFirstOption('#calcms_series_name_'
				+ calcms.getJsName(project));
		calcms.selectFirstOption('#calcms_category_'
				+ calcms.getJsName(project));
	}

	// search events
	calcms.selectSearchEventListener = function selectSearchEventListener() {
		var project = calcms.getProject();

		calcms.showSearchResultsByProject(project, calcms.getSearchElement()
				.val(), calcms.isArchive());
		calcms.selectFirstOption('#calcms_series_name_'
				+ calcms.getJsName(project));
		calcms.selectFirstOption('#calcms_category_'
				+ calcms.getJsName(project));

		calcms.registerOnChangeArchive(function() {
			calcms.showSearchResultsByProject(project, calcms
					.getSearchElement().val(), calcms.isArchive());
		});
	}

	// show events for selected category of project
	calcms.selectCategory = function selectCategory(project, category) {
		calcms.showEventsByProjectAndCategory(project, category, calcms
				.isArchive());
		calcms.selectFirstOption('#calcms_series_name_'
				+ calcms.getJsName(project));
		calcms.resetSearch();

		calcms.registerOnChangeArchive(function() {
			calcms.showEventsByProjectAndCategory(project, category, calcms
					.isArchive());
		});
	}

	// show events for selected series of project
	calcms.selectSeries = function selectSeries(project, seriesName) {
		calcms.showEventsByProjectAndSeriesName(project, seriesName, calcms
				.isArchive());
		calcms.selectFirstOption('#calcms_category_'
				+ calcms.getJsName(project));
		calcms.resetSearch();

		calcms.registerOnChangeArchive(function() {
			calcms.showEventsByProjectAndSeriesName(project, seriesName, calcms
					.isArchive());
		});
	}

	// calendar events
	calcms.selectMonthEventListener = function selectMonthEventListener(month) {
		calcms.showCalendarAndEventsByMonth(month);
	}

	calcms.selectWeekdayEventListener = function selectWeekdayEventListener(
			start_date, end_date, weekday) {
		calcms.showEventsByWeekday(start_date, end_date, weekday);
	}

	calcms.selectDateRangeEventListener = function selectDateRangeEventListener(
			from, till) {
		calcms.showEventsByDateRange(from, till);
	}

	calcms.selectDateEventListener = function selectDateEventListener(date) {
		calcms.showEventsByDate(date);
	}

	// initial initialize
	function initCalcms() {
		calcms.set('base_url', '');

		calcms.set('calendar_url', '/agenda/kalender');
		calcms.set('menu_url', '/agenda/menu');

		calcms.set('events_url', '/agenda/sendungen');
		calcms.set('list_url', '/agenda/sendung');
		calcms.set('next_series_url', '/programm/sendung/serie_plus');
		calcms.set('prev_series_url', '/programm/sendung/serie_minus');

		calcms.set('ical_url', '/agenda/ical');
		calcms.set('feed_url', '/agenda/feed/');
		calcms.set('playlist_url', '/agenda/playlist/');

		calcms.set('search_url', '/agenda/suche/');
		calcms.set('search_category_url', '/agenda/kategorie/');
		calcms.set('search_series_name_url', '/agenda/sendereihe/');

		calcms.set('category_url', '/agenda/kategorien/');
		calcms.set('series_name_url', '/agenda/sendereihen/');

		calcms.set('comments_url', '/agenda/kommentare/');
		calcms.set('add_comment_url', '/agenda/kommentar_neu/');
		calcms.set('newest_comments_url', '/agenda/neueste_kommentare/');

		return true;
	}

	var loadedSearchComponents = 0;
	// load projects, series and categories and show search fields
	// remove empty projects if both series and categories have been loaded
	calcms.showAdvancedSearch = function showAdvancedSearch(id) {
		searchReady = 0;
		var element = $('#calcms_enhanced_search');
		if (element.length == 0)
			return;

		if (element.css('display') == 'none') {
			var url = calcms.get('category_url');
			calcms.updateContainer('calcms_categories', url, 1, function() {
				calcms.selectProject();
				loadedSearchComponents++;
				if (loadedSearchComponents == 2) {
					calcms.removeEmptyProjects();
				}
			});

			url = calcms.get('series_name_url');
			calcms.updateContainer('calcms_series_names', url, 1, function() {
				calcms.selectProject();
				loadedSearchComponents++;
				if (loadedSearchComponents == 2) {
					calcms.removeEmptyProjects();
				}
			});
		} else {
			calcms.showProjectCategories(calcms.getProject());
			calcms.showProjectSeriesNames(calcms.getProject());
		}

		$("#" + id).slideToggle();
	}

	calcms.insertDeskNextShows = function insertDeskNextShows(desk) {
		var url = '/agenda/suche/all/' + desk + '/kommende/';
		calcms.updateContainer('showDesk', url, 1);
		return false;
	}

	calcms.insertDeskPrevShows = function insertDeskPrevShows(desk) {
		var url = '/agenda/suche/all/' + desk + '/vergangene/';
		calcms.updateContainer('showDesk', url, 1);
		return false;
	}

    /*
	function insertDeskDetails() {
		var pattern = new RegExp(/redaktion\/(.*)$/);
		var matchs = pattern.exec(document.location.href);
		if ((matchs != null) && (matchs.length > 0) && (matchs[1] != '')) {
			var desk = $('#center h2:first').text();
			desk = desk.replace('Redaktion: ', '');
			desk = escape(desk);
			$('#center .content').append(
					'<div>' + '<a onclick="insertDeskPrevShows(\'' + desk
							+ '\');return false;" href="#">«letzte«</a>'
							+ ' Sendungen '
							+ '<a onclick="insertDeskNextShows(\'' + desk
							+ '\');return false;" href="#">»nächste»</a>'
							+ '<div id="showDesk" />' + '</div>');
		}
	}
	*/

    /*
	function fixBlogEntries() {
		if (document.location.href.match('/redaktionen/')
				|| document.location.href.match('/redaktionen?')
				|| document.location.href.match('/redaktionen$')) {
			$('img.image-thumbnail').css('width', '3em');
			$('img.image-thumbnail').css('height', '3em');
			$('div.image-attach-teaser').css('width', '3em');
			$('div.node').css('padding', '0');
			$('div.node').css('margin', '0');
			$('#center .submitted').remove();
			$('#center .clear-block h2 a')
					.each(
							function(index) {
								$(this)
										.html(
												$(this)
														.text()
														.replace('Redaktion: ',
																'<font color="gray">Redaktion:</font> '));
								if ($(this).text().match(/Information:/))
									$(this).remove();
							})

		}
	}
    */

    /*
	function setImageSize() {
		var image = '#calcms_list div.content img';
		var size = $(window).width();
		size = Math.floor(size * 0.16);
		$(image).css('width', size + 'px');
		$(image).css('height', size + 'px');
		if (size > 200) {
			$(image).each(function(index) {
				var url = $(this).attr('src');
				if (url != null) {
					url = url.replace('/thumbs/', '/images/');
					console.log(url);
					$(this).attr('src', url);
				}
			});
		} else {
			$(image).each(function(index) {
				var url = $(this).attr('src');
				if (url != null) {
					url = url.replace('/images/', '/thumbs/');
					$(this).attr('src', url);
				}
			});
		}
	}
    */	

	function setThumbs() {
		$('#calcms_playlist img').each(function(index) {
			var url = $(this).attr('src');
			if (url != null) {
				url = url.replace('/images/', '/thumbs/');
				$(this).attr('src', url);
			}
		});
	}

    /*
	function addCommentsOnAgendaPages() {
		if (calcms.contains(window.location.href, '/programm/')
				|| calcms.contains(window.location.href, '/agenda/')) {
			$('#sidebar-right')
					.append(
							'<div id="block-block-2" class="clear-block block block-block"><h2>Kommentare</h2><div class="content">'
									+ '<div id="calcms_newest_comments">Bitte warten…</div>'
									+ '</div></div>');
		}
	}
	*/

	function scrollNextEvent() {
		if ($('#calcms_running_event').length == 0)
			return;
		$('#playlist_container').scrollLeft(0);
		setInterval(nextSlideEvent, 10000);
	}

	var numberOfComingShows = 100;
	var slideCount = 0;
	var slideOffset = 1;
	var slideEvents = 1;

	// slideEvents will be updated at onmouseenter/leave handler at
	// playlist_long
	function nextSlideEvent() {
		if (slideEvents == 0)
			return;
		if ($('#coming_shows a').length == 0)
			return;
		if (slideCount == 0) {
			numberOfComingShows = $('#coming_shows a').length;
			$('#playlist_container').scrollLeft(0)
			$('#playlist_container').css('overflow', 'auto');
			$('#playlist_container').css('-webkit-overflow-scrolling', 'touch');
			$('#playlist_container').css('height', '150');
			$('#coming_shows').css('white-space', 'nowrap');
			$('#coming_shows').css('overflow-x', 'hidden');
			$('#coming_shows').css('height', '150');
		}

		// console.log(slideCount+" "+slideOffset)
		$('#playlist_container').animate({
			scrollLeft : slideCount * 115 + "px"
		}, 5000);

		if (slideCount < 0)
			slideOffset = 1
		if (slideCount > numberOfComingShows + 1 - $('#coming_shows').width()
				/ 100)
			slideOffset = -1
		slideCount += slideOffset;
	}

	function mobilise() {
		if (!navigator.userAgent.match(/Mobi/))
			return;

		$('#wrapper #container #sidebar-left').before(
				$('#wrapper #container #center'));
		$('#wrapper #container #sidebar-left').before(
				$('#wrapper #container #sidebar-right'));

		$('body.sidebars').css('min-width', '100%');
		$('body.sidebar-left').css('min-width', '100%');
		$('body.sidebar-right').css('min-width', '100%');

		$('#wrapper #container .sidebar').css('width', '100%');
		$('#wrapper #container').css('width', '100%');
		$('#wrapper #container').css('max-width', '100%');
		$('#wrapper #container').css('margin', '0');
		$('#wrapper #container').css('padding', '0');

		$('#center').css('margin', '0');
		$('#center #squeeze').css('margin', '0');
		$('#center *').css('margin-left', '0');
		$('#center *').css('margin-right', '0');
		$('#center .right-corner').css('position', 'static');
		$('#center .right-corner').css('left', '0');
		$('#center .right-corner').css('padding-left', '0');
		$('#center .right-corner').css('padding-right', '0');
		$('#center .right-corner').css('background-image', 'url()');
		$('#center .left-corner').css('position', 'static');
		$('#center .left-corner').css('padding-left', '0');
		$('#center .left-corner').css('padding-right', '0');
		$('#center .left-corner').css('background-image', 'url()');
		$('#center *').css('background-image', 'url()');

		$('#wrapper #container #header').css('height', '100px');

		var padding = '0.5em'
		$('#center .left-corner').css('padding-left', padding);
		$('#center .left-corner').css('padding-right', padding);
		$('#wrapper #container #sidebar-left').css('padding-left', padding);
		$('#wrapper #container #sidebar-left').css('padding-right', padding);

		// $('*').css('background','none');
		// $('#sidebar-left div.content').css('text-align','center');
		// $('#sidebar-left *').css('margin-left','0');
		// $('#sidebar-left *').css('margin-right','0');
		// $('#sidebar-right *').css('margin-left','0');
		// $('#sidebar-right *').css('margin-right','0');
		// $('#sidebar-left').css('width','90%');
		$('.node').css('padding-left', '0');
		$('.node').css('padding-right', '0');

		$('#calcms_search input').css("padding", "1em");
		$('#calcms_search select').css("padding", "1em");

		var menu = "ul.links.primary-links";
		$(menu).addClass('mobileMenu');
		$(menu).before('<div id="mobileMenuButton"></div>');
		$(menu).hide();

		var menu2 = "ul.links.secondary-links";
		$(menu2).each(function() {
			$(menu).append($(this).html());
		})
		$(menu2).remove();

		$('#calcms_calendar table').css('width', '90%');

		// move footer down
		var footer = $('#wrapper #footer').html();
		$('body').append(footer);
		$('#wrapper #footer').remove();

		$("#mobileMenuButton").click(function() {
			$(menu).slideToggle();
			return false;
		});
	}

	function initSearch() {
		var base = $('#calcms_search_show_details');
		var elem = $('#calcms_search_show_details #plus');
		if (elem.length == 0) {
			base.append('<span id="plus"> ▼ </span>');
			base.prepend('<span id="plus"></span>');

		}
	}

    var isCalcms=false;
    function initWordpress(){
        $('header.entry-header').each( function(){
            var elem=$(this);
            $(this).find("h1").each( function(){
                if ( $(this).text() == "calcms" ){
                    isCalcms=true;
                    $(this).text("Programm");
                }
            });
        });

        $('div.site-info').remove();
        
        if (isCalcms==false){
            $('#calcms_calendar').parent().parent().remove();
            $('#calcms_menu').parent().parent().remove();
            $('#calcms_search').parent().parent().remove();
            $('#calcms_playlist').parent().parent().remove();
            $('#calcms_newest_comments').parent().parent().remove();
        }
    }

	function initAll() {
		initCalcms();
		//initWordpress();
		//addCommentsOnAgendaPages();
		calcms.showPlaylist();
		calcms.showNewestComments();
		// insertDeskDetails();
		// fixBlogEntries();
		calcms.removeCurrentPlayingHeader();
		// setImageSize();
		// setThumbs();
		// scrollNextEvent();
		//initSlider();
		// mobilise();
		initSearch();
		console.log("calcms inited")
	}

	$(document).ready(function() {
		initAll();
	});

}(jQuery, calcms));

