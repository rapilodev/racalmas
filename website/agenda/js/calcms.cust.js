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
        calcms.searchEvents({
            project : project, 
            search : calcms.getSearchElement().val(), 
            archive : calcms.isArchive()
        });
        calcms.selectFirstOption('#calcms_series_name_'
                + calcms.getJsName(project));

        calcms.registerOnChangeArchive(function() {
            calcms.searchEvents({
                project : project, 
                search : calcms.getSearchElement().val(), 
                archive : calcms.isArchive()
            });
        })
    }

    // show events for selected series of project
    calcms.selectSeries = function selectSeries(project, seriesName) {
        calcms.searchEvents({
            project : project, 
            series : seriesName, 
            archive : calcms.isArchive()
        });
        calcms.resetSearch();

        calcms.registerOnChangeArchive(function() {
            calcms.searchEvents({
                project : project, 
                series: seriesName, 
                archive : calcms.isArchive()
            });
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
        calcms.set('next_episode_url', '/programm/event/next_episode');
        calcms.set('prev_episode_url', '/programm/event/previous_episode');

        calcms.set('ical_url', '/agenda/ical');
        calcms.set('feed_url', '/agenda/feed/');
        calcms.set('playlist_url', '/agenda/playlist/');

        calcms.set('search_url', '/agenda/');
        calcms.set('series_name_url', '/agenda/series/');

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
        url = calcms.get('series_name_url');
        calcms.updateContainer('calcms_series_names', url, function() {
            calcms.selectProject();
            loadedSearchComponents++;
            if (loadedSearchComponents == 2) {
                calcms.removeEmptyProjects();
            }
        });
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
        try { $([document.documentElement, document.body]).scrollTop( elem.offset().top+offset ) } catch(e){};
    }

    function addPrevEvent(id){
        $('a.load-prev').remove();
        $('div.event-base').first().prepend('<a class="load-prev">davor</a>');
        $('a.load-prev').on( "click", function(){
            var url = "/programm/sendung/"+id+'.html';
            window.location=url;
        })
    }

    function addPrevSection(till){
        $('a.load-prev').remove();
        $('div.events-base').first().prepend('<a class="load-prev">davor…</a>');
        $('a.load-prev').on( "click", function(){
            till.setDate(till.getDate())
            var from = new Date(till.getTime());
            from.setDate(from.getDate()-2);
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
            window.location = url;
        });
    }

    function addNextSection(from){
        $('a.load-next').remove();
        $('div.events-base').last().append('<a class="load-next">danach…</a>');
        $('a.load-next').on( "click", function(){
            from.setDate(from.getDate()+1)
            var till = new Date(from.getTime());
            till.setDate(till.getDate()+2);
            var url = "/programm/events/"+formatDate(from)+'_'+formatDate(till)+'.html';
            fetch( url )
            .then( response => response.text())
            .then( text => {
                $('div.events-base').last().after(text);
                $('div.events-base').last().css("display","none").fadeIn("1s");
                till.setDate(till.getDate()-1);
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
    }

    function replaceLogo() {
      const logo = `
    <svg xmlns="http://www.w3.org/2000/svg" width="220" height="95" viewBox="0 0 71.36 26.4" style="display: inline;" class="custom-logo">
      <path style="fill:#123;stroke-width:.12574257" d="M110.33 113.65c-6.49-1.26-11.13-6.72-11.13-13.1 0-7.24 6.13-13.16 13.64-13.17 3.67 0 7 1.3 9.6 3.75a12.96 12.96 0 0 1 4.13 10.11 13.4 13.4 0 0 1-10.03 12.15c-1 .27-1.52.33-3.26.38-1.42.03-2.35 0-2.95-.12zm5.21-3.5a10.2 10.2 0 0 0 7.31-6.9c.43-1.36.43-3.91 0-5.27a9.85 9.85 0 0 0-2.24-3.9 9.98 9.98 0 0 0-7.7-3.31c-1.75 0-3.03.26-4.46.9a10.36 10.36 0 0 0-5.4 5.9 7.1 7.1 0 0 0-.43 2.68 7.41 7.41 0 0 0 .22 2.64 9.58 9.58 0 0 0 2.96 4.88 10.66 10.66 0 0 0 9.74 2.39zm-7.85-4.23c-.34-.07-.39-.15-.48-.71a72.5 72.5 0 0 1-.07-5.12c.03-3.47.08-4.52.2-4.65.13-.12.67-.16 2.08-.16 2.4.01 2.75.12 3.32 1.06.67 1.1.67 2.16 0 3.16-.25.38-1.2.97-1.88 1.17-.2.06-.22.29-.22 2.47 0 1.41-.05 2.5-.13 2.64-.12.22-.26.24-1.29.23a12 12 0 0 1-1.53-.1zm3.66-7.2c.39-.37.4-1.06.02-1.46-.4-.42-1.03-.39-1.5.08-.45.45-.46.76-.04 1.26.41.48 1.08.53 1.52.11zm3.72 7.18-.28-.12v-5.03c0-4.87 0-5.04.25-5.29.23-.22.42-.25 1.87-.25 1.37 0 1.64.03 1.7.2.04.11.08 2.48.08 5.26 0 3.76-.04 5.1-.15 5.2-.18.19-3.03.2-3.47.03zm22.65.25c-1.27-.26-1.95-.98-2.02-2.12-.04-.56.01-.8.24-1.2.42-.72 1.07-1.03 3.07-1.46 1.93-.43 2.35-.58 2.41-.92.1-.45-.33-.71-1.14-.71-.7 0-.78.03-1.16.45l-.41.45-1.24-.15c-1.52-.19-1.61-.25-1.36-.86.27-.64.73-1.08 1.49-1.42.58-.26.83-.29 2.59-.3 2.08 0 2.63.11 3.35.64.75.57.85.97.94 3.9.05 1.45.13 2.85.18 3.1l.09.48h-2.77l-.16-.39c-.08-.2-.2-.36-.23-.34l-.9.44c-.9.44-2.06.6-2.97.41zm2.77-1.8c.61-.26.96-.77.96-1.42 0-.34-.06-.55-.15-.55-.47 0-2.25.66-2.37.88-.49.92.42 1.56 1.56 1.08zm8.12 1.81c-1.62-.34-2.63-1.96-2.63-4.22 0-2.4 1.13-3.9 3.05-4.05.86-.07 1.55.09 2.12.48.18.13.37.24.4.24.05 0 .08-.75.08-1.67 0-.91.05-1.74.1-1.83.08-.12.48-.15 1.55-.12l1.43.03.04 5.51.03 5.5-1.42-.03-1.41-.04-.04-.4c-.05-.48-.15-.51-.48-.15-.55.61-1.85.96-2.82.75zm2.2-2.32c.57-.24.85-.82.86-1.77 0-.95-.27-1.53-.86-1.78-.8-.33-1.49.11-1.71 1.1-.26 1.14.2 2.4.93 2.54l.32.07.46-.16zm14.13 2.32a4.37 4.37 0 0 1-3.1-2.2c-.3-.57-.34-.77-.34-1.9 0-1.05.05-1.34.3-1.84a4.52 4.52 0 0 1 2-1.95c.67-.33.83-.35 2.23-.35 1.36 0 1.58.04 2.22.33.86.4 1.59 1.1 2 1.93.25.53.3.81.3 1.82 0 1.06-.03 1.28-.35 1.92a4.14 4.14 0 0 1-2.14 1.96c-.76.29-2.3.42-3.12.28zm2-2.45c.46-.42.47-.46.52-1.43.05-1.16-.15-1.73-.73-2.07a1.4 1.4 0 0 0-1.98.57c-.3.55-.3 2.02 0 2.57.46.88 1.45 1.04 2.2.36zm-37.98 2.24c-.05-.05-.09-1.8-.09-3.89 0-3.1.03-3.83.18-3.94.11-.1.6-.14 1.41-.11l1.24.03.04.41c.05.5.14.5.54.08.61-.66 1.3-.82 2.29-.54.26.07.5.2.54.3.03.08-.14.59-.38 1.12l-.44.97-.57-.08c-.43-.07-.65-.03-.9.13-.59.38-.72.94-.8 3.33l-.07 2.2-1.45.04c-.8.02-1.5 0-1.54-.05zm27.86-3.92.03-3.99h2.89l.04 4 .03 3.99h-3.03zm.02-5.1c-.03-.1-.05-.56-.03-1.04l.04-.87h2.89v2.01l-1.41.04c-1.12.03-1.44 0-1.49-.14z" transform="translate(-99.2 -87.38)"></path>
    </svg>
      `;
      $('div.site-branding a').html(logo);
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
        replaceLogo();
        calcms.showAdvancedSearch();
        console.log("calcms inited")
    });

}(jQuery, calcms));
