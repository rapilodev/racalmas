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
            calcms.updateContainer('calcms_series_names', url, function() {
                calcms.selectProject();
                loadedSearchComponents++;
                if (loadedSearchComponents == 2) {
                    calcms.removeEmptyProjects();
                }
            });
        } else {
            calcms.showProjectSeriesNames(calcms.getProject());
        }
        calcms.toggle(document.querySelector('#' + id));
    }

    calcms.insertDeskNextShows = function insertDeskNextShows(desk) {
        var url = '/agenda/suche/all/' + desk + '/kommende/';
        calcms.updateContainer('showDesk', url);
        return false;
    }

    calcms.insertDeskPrevShows = function insertDeskPrevShows(desk) {
        var url = '/agenda/suche/all/' + desk + '/vergangene/';
        calcms.updateContainer('showDesk', url);
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
                calcms.updateContainer("#result", editorsUrl);
            }
        }
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

    function formatDate(date) {
        var d = new Date(date),
            month = '' + (d.getMonth() + 1),
            day   = '' + d.getDate(),
            year  = d.getFullYear();
        if (month.length < 2) month = '0' + month;
        if (day.length < 2)   day = '0' + day;
        return [year, month, day].join('-');
    }

    function scrollTo(elem, offset, duration){
        if (elem==null)     return;
        if (offset==null)   offset=0;
        if (duration==null) duration=500;
        $([document.documentElement, document.body]).scrollTop( elem.offset().top+offset )
    }

    function addPrevEvent(id){
        $('a.load-prev').remove();
        $('div.event-base').first().prepend('<a class="load-prev">davor</a>');
        $('a.load-prev').on( "click", function(){
            var url = "/programm/sendung/"+id+'.html';
            window.location.href=url;
        })
    }

    function addPrevSection(till){
        $('a.load-prev').remove();
        $('div.events-base').first().prepend('<a class="load-prev">davor…</a>');
        $('a.load-prev').on( "click", function(){
            till.setDate(till.getDate())
            var from = new Date(till.getTime());
            from.setDate(from.getDate()-7);
            var url = "/programm/events/"+formatDate(from)+'_'+formatDate(till)+'.html';
            fetch( url )
            .then( response => response.text())
            .then( text => {
                var offset = $('a.load-prev').offset().top
                $('div.events-base').first().before(text);
                $('div.events-base').first().css("display","none").fadeIn("1s");
                scrollTo( $('a.load-prev'), -offset, 0 );
                addPrevSection(from);
            })
        });
    }

    function addNextEvent(id){
        $('a.load-next').remove();
        $('div.event-base').last().append('<a class="load-next">danach</a>');
        $('a.load-next').on( "click", function(){
            var url = "/programm/sendung/"+id+'.html';
            window.location.href=url;
        });
    }

    function addNextSection(from){
        $('a.load-next').remove();
        $('div.events-base').last().append('<a class="load-next">danach…</a>');
        $('a.load-next').on( "click", function(){
            from.setDate(from.getDate()+1)
            var till = new Date(from.getTime());
            till.setDate(till.getDate()+7);
            var url = "/programm/events/"+formatDate(from)+'_'+formatDate(till)+'.html';
            fetch( url )
            .then( response => response.text())
            .then( text => {
                $('div.events-base').last().after(text);
                $('div.events-base').last().css("display","none").fadeIn("1s");
                addNextSection(till);
            })
        });
    }

    function initEventScroll(){
        var values = window.location.href.match(/programm/);
        if (!values) return;

        var first_date = $('div.events-base').data('first-date');
        if (first_date) addPrevSection(new Date( first_date.split("-") ) );

        var last_date  = $('div.events-base').data('last-date');
        if (last_date)  addNextSection(new Date( last_date.split("-") ) );

        var prev = $('div.event-base').data('prev-event');
        if (prev) addPrevEvent(prev);

        var next = $('div.event-base').data('next-event');
        if (next) addNextEvent(next);

        $(window).scroll( function() {
            /*
            clearTimeout( $.data( this, "scrollCheck" ) );
            $("div.event div.excerpt").css("opacity","0");
            $.data( this, "scrollCheck", setTimeout(function() {
                $("div.event div.excerpt").css("opacity","0.7");
            }, 100) );
            */
            if($(window).scrollTop() + $(window).height() == $(document).height()) {
                $('a.load-next').click();
            }
            //if($(window).scrollTop() == 0) $('a.load-prev').click();
        });
    }

    $(document).ready(function() {
        if (window.location.href.match(/\/programm\//)) scrollTo( $("h1"), -16,0 );
        initCalcms();
        initWordpress();
        calcms.showPlaylist();
        calcms.showNewestComments();
        calcms.insertEditors();
        initSearch();
        initEventScroll();
        console.log("calcms inited")
    });

}(jQuery, calcms));
