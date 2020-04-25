var calcms_settings = new Array();

(function($, calcms) {

    // show current project
    calcms.selectProject = function selectProject() {
        var project = calcms.getProject();
        console.log("project=" + project)

        calcms.clearOnChangeArchive();
        calcms.showProjectSeriesNames(project);
        calcms.selectFirstOption('#calcms_series_name_'
                + calcms.getJsName(project));
    }

    // search events
    calcms.selectSearchEventListener = function selectSearchEventListener() {
        var project = calcms.getProject();

        calcms.showSearchResultsByProject(project, calcms.getSearchElement()
                .val(), calcms.isArchive());
        calcms.selectFirstOption('#calcms_series_name_'
                + calcms.getJsName(project));

        calcms.registerOnChangeArchive(function() {
            calcms.showSearchResultsByProject(project, calcms
                    .getSearchElement().val(), calcms.isArchive());
        });
    }

    // show events for selected series of project
    calcms.selectSeries = function selectSeries(project, seriesName) {
        calcms.showEventsByProjectAndSeriesName(project, seriesName, calcms
                .isArchive());
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
        calcms.set('search_series_name_url', '/agenda/sendereihe/');

        calcms.set('series_name_url', '/agenda/sendereihen/');

        calcms.set('comments_url', '/agenda/kommentare/');
        calcms.set('add_comment_url', '/agenda/kommentar_neu/');
        calcms.set('newest_comments_url', '/agenda/neueste_kommentare/');

        return true;
    }

    var loadedSearchComponents = 0;
    // load projects, series and show search fields
    // remove empty projects if series have been loaded
    calcms.showAdvancedSearch = function showAdvancedSearch(id) {
        searchReady = 0;
        var element = $('#calcms_enhanced_search');
        if (element.length == 0) return;

        if (element.css('display') == 'none') {
            url = calcms.get('series_name_url');
            calcms.updateContainer('calcms_series_names', url, 1, function() {
                calcms.selectProject();
                loadedSearchComponents++;
                if (loadedSearchComponents == 2) {
                    calcms.removeEmptyProjects();
                }
            });
        } else {
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

    calcms.insertEditors = function insertEditors() {
        var url = document.location.href;

        var mapping = {
            "studio\-ansage" : "/agenda/redaktionen-studio-ansage",
            "studio\-pi\-radio" : "/agenda/redaktionen-piradio",
            "studio\-frb" : "/agenda/redaktionen-frb",
            "studio\-colabo" : "/agenda/redaktionen-colabo-radio",
            "studio\-frrapo" : "/agenda/redaktionen-frrapo"
        };

        for ( var key in mapping) {
            var editorsUrl = mapping[key];
            var pattern = new RegExp(key);
            var matchs = pattern.exec(url);
            if ((matchs != null) && (matchs.length > 0)) {
                console.log("matchs " + url)
                $('div.entry-content').append('<div id="result"> </div>')
                $("#result").load(editorsUrl)
            }
        }
    }

    var setupSliderTimer;
    function initSlider() {
        setupSliderTimer = setInterval(function() {
            setupSlider();
        }, 1000);
    }

    var isSliderInited = 0;
    var sliderTimer;
    function setupSlider() {
        console.log("setupSlider")
        if (isSliderInited == 1) return;
        isSliderInited = 1;
        clearInterval(setupSliderTimer);
        $('#playlist_container').scrollLeft(0);

        numberOfComingShows = $('#coming_shows a').length;

        $('#playlist_container').mouseenter(function() {
            slideEvents = 0;
        });

        $('#playlist_container').mouseleave(function() {
            slideEvents = 1;
        });

        nextSlideEvent();
        sliderTimer = setInterval(nextSlideEvent, 10000);
        console.log("setupSlider done")
    }

    var numberOfComingShows = 100;
    var slideCount = 0;
    var slideOffset = 1;
    var slideEvents = 1;

    // slideEvents will be updated at onmouseenter/leave handler at
    // playlist_long
    function nextSlideEvent() {
        // console.log("slideEvent")
        if (slideEvents == 0) return;
        if ($('#coming_shows a').length == 0) return;

        // console.log(slideCount+" "+slideOffset)
        var item = $('#playlist_container .eventContainer').first();
        var width = item.outerWidth();
        // console.log("width="+width);
        $('#playlist_container').animate({
            scrollLeft : slideCount * width + "px"
        }, 1000);

        if (slideCount < 0) slideOffset = 1
        if (slideCount > numberOfComingShows + 1 - $('#coming_shows').width()
                / 100) slideOffset = -1
        slideCount += slideOffset;
    }

    function initSearch() {
        var base = $('#calcms_search_show_details');
        var elem = $('#calcms_search_show_details #plus');
        if (elem.length == 0) {
            base.append('<span id="plus"> ▼ </span>');
            base.prepend('<span id="plus"></span>');
        }
    }

    var isCalcms = false;
    function initWordpress() {
        $('header.entry-header').each(function() {
            var elem = $(this);
            $(this).find("h1").each(function() {
                if ($(this).text() == "Programm") {
                    isCalcms = true;
                    $(this).text("Programm");
                }
            });
        });
        $('div.site-info').remove();

        if (isCalcms == false) {
            $('#calcms_calendar').parent().parent().remove();
            $('#calcms_menu').parent().parent().remove();
            $('#calcms_search').parent().parent().remove();
            $('#calcms_playlist').parent().parent().remove();
            $('#calcms_newest_comments').parent().parent().remove();
        }
    }

    $(document).ready(function() {
        initCalcms();
        initWordpress();
        calcms.showPlaylist();
        calcms.showNewestComments();
        calcms.insertEditors();
        initSlider();
        initSearch();
        console.log("calcms inited")
    });

}(jQuery, calcms));
