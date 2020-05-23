var days=1;

var leftMouseButton=1;
var middleMouseButton=2;
var rightMouseButton=3;

function openNewTab(url){
    window.open(url, '_blank');
}

function selectCheckbox(selector){
    $(selector).each(function(){
        $(this).prop('checked', 'checked');
    })   
}

function unselectCheckbox(selector){
    $(selector).each(function(){
        $(this).removeProp('checked');
    })   
}

function isChecked(selector){
    return $(selector).prop('checked');
}

function cancel_edit_event(){
    $('#calendar').show();
    $('#calendar_weekdays').show();
    $('#event_editor').hide();
    resizeCalendarMenu();
    return false;
}

function setupMenuHeight(){
    if ($('#calendar').length>0){
        var top=$('#calcms_nav').height();

        $('#toolbar').css("top", top);
        $('#toolbar').css("position", "absolute");
        top+=$('#toolbar').height()+2;

        var weekdays = document.querySelector("#calendar_weekdays");
        $('#calendar_weekdays').css("top", top);

        var weekday_height=30;
        weekdays.querySelectorAll("table td div").forEach( 
            function(div) {
                var height = div.offsetHeight + 14;
                if (height>weekday_height) weekday_height=height;
            } 
        );
        
        top+=weekday_height+1;
        $('#calendar').css("top", top);
        return top;
    } else {
        var top = $('#calcms_nav').height();
        $('#content').css("top", top);
        return top;
    }
}

function resizeCalendarMenu(){
    $('#calendar').hide();
    $('#calendar_weekdays').css("visibility","hidden");

    //after getting menu heigth, hide calendar again
    var menuHeight = setupMenuHeight();

    var width  = $(window).width()-0;
    var height = $(window).height()-menuHeight;

    if($('#calendar').css('display')=='none'){
        $('body #content').css('max-width', '960');
    }else{
        $('body #content').css('max-width', width);
    }
    $('div#calendar').css('width', width);
    $('div#calendar_weekdays').css('width', width);
    $('div#calendar').css('height', height);

    // remove border for scroll
    $('#calendar table').css('width', width-20);
    $('#calendar_weekdays table').css('width', width-20);
    $('#calendar table').css('height', height);
    
    //set spacing between table columns
    var columnSpacing=Math.round($(window).width()/72);
    if(columnSpacing<0) columnSpacing=0;
    columnSpacing=Math.ceil(columnSpacing);
    
    $('div.week').css('width',       columnSpacing);
    $('div.week').css('margin-left',-columnSpacing);

    //calculate cell-width
    var cell_width=(width-100)/(days-1);
    if($(window).width()<720){
        $('#calendar td.week').hide();
        cell_width=(width-100)/(days)-4;
    }else{
        $('#calendar td.week').show();
        cell_width=(width-100)/(days)-columnSpacing;
    }

    var with_param='width';
    var cw=cell_width.toFixed();

    $('#calendar').show();
    $('#calendar_weekdays').css("visibility","visible");
}


function setFilter(){
    var filter=$('#filter').val();
    if(filter=='conflicts'){
        $('#content').addClass("conflicts");
    }else{
        $('#content').removeClass("conflicts");
        $('.event').each(function(){
            if($(this).hasClass(filter)){
                $(this).addClass("marked");
            }else{
                $(this).removeClass("marked");
            }
        });
    }
}

// preselect options in select boxes
function setSelectedOptions(){
    $('#content select').each(
        function(){
            var value=$(this).attr('value');
            if (value==null) return;
            $(this).children().each(
                function(){
                    if ($(this).attr('value')==value){
                        $(this).attr('selected','selected');
                    }
                }
            );
        }
    );
}

function updateUrls(url){
    if(url==null){
        url=window.location.href;
        url=updateUrlParameters(url);
    }
    url=removeUrlParameter(url, 'part');    

    //replace current in history
    history.pushState(null, null, url);
    appendHistory(url,'replace');
}

function updateUrlParameters(url){

    var range=$('#range').val();
    if (range=='events'){
        url=setUrlParameter(url, 'list', 1);
    }else{
        url=setUrlParameter(url, 'range', $('#range').val());
    }

    if(isChecked('#show_schedule')){
        url=setUrlParameter(url, 's', 1);
    }else{
        url=setUrlParameter(url, 's', 0);
    }

    if(isChecked('#show_events')){
        url=setUrlParameter(url, 'e', 1);
    }else{
        url=setUrlParameter(url, 'e', 0);
    }

    if(isChecked('#show_worktime')){
        url=setUrlParameter(url, 'w', 1);
    }else{
        url=setUrlParameter(url, 'w', 0);
    }

    if(isChecked('#show_playout')){
        url=setUrlParameter(url, 'p', 1);
    }else{
        url=setUrlParameter(url, 'p', 0);
    }

    var filter=$('#filter').val();
    if(filter!='no markup')
        url=setUrlParameter(url, 'filter',     $filter);
    url=setUrlParameter(url, 'project_id', $('#project_id').val());
    url=setUrlParameter(url, 'studio_id',  $('#studio_id').val());
    url=setUrlParameter(url, 'day_start',  $('#day_start').val());

    return url;
}

function show_events(){
    if(isChecked('#show_events')){
        $('#calendar .event').css("display",'');
        $('#event_list .event').css("display",'');
    }else{
        $('#calendar .event').css("display",'none');
        $('#event_list .event').css("display",'none');
    }
}

function show_schedule(){
    if(isChecked('#show_schedule')){
        $('#calendar .schedule').css("display",'');
        $('#event_list .schedule').css("display",'');
    }else{
        $('#calendar .schedule').css("display",'none');
        $('#event_list .schedule').css("display",'none');
    }
}

function show_worktime(){
    if(isChecked('#show_worktime')){
        $('#calendar .work').css("display",'');
    }else{
        $('#calendar .work').css("display",'none');
    }
}

function show_playout(){
    if(isChecked('#show_playout')){
        $('#calendar .play').css("display",'');
    }else{
        $('#calendar .play').css("display",'none');
    }
}

//get date and time from column and row to select a timeslot
function getNearestDatetime(){
    var date="test";
    var hour="00";
    var minute="00";

    var xMin=9999999;
    var yMin=9999999;
    var minutes=0;

    //get date
    $('#calendar_weekdays div.date').each(
        function(){
            var xpos   = $(this).offset().left;
            var offset = $(this).width()/2;
            var delta=Math.abs(mouseX-xpos-offset);
            if (delta<xMin){
                xMin=delta;
                date= $(this).attr('date');
            }
        }
    );

    //get time
    $('#calendar div.time').each(
        function(){
            var ypos   = $(this).offset().top;
            var offset = $(this).height()/2;
            var delta=(mouseY-ypos-offset);
            var distance=Math.abs(delta);
            if (distance<yMin){
                yMin=delta;
                hour= $(this).attr('time');
                minute='30';
                if(delta<0) minute='00';
            }
        }
    );

    //add a day, if time < startOfDay
    if(hour<startOfDay){
        date=addDays(date,1);
        date=formatDate(date);
    }

    var minute=0;
    yMin=9999999999;
    $('#calendar div.time').each(
        function(){
            var ypos   = $(this).offset().top;
            var offset = $(this).height()/2;
            var delta=(mouseY-ypos-offset);
            var distance=Math.abs(delta);
            if (distance<yMin){
                yMin=delta;
                hour= $(this).attr('time');
                var height=$(this).height()+14;
                var m=((delta+height*1.5)-8) % height;
                m=m*60/height;
                minute=Math.floor(m/5)*5;
                if (minute<10)minute='0'+minute;
            }
        }
    );
    return date+" "+hour+":"+minute+ " ";
}

var mouseX=0;
var mouseY=0;
var mouseMoved=0;
var mouseUpdate=0;
function showMouse(){
    //if mouse moves save position
    $( "#calendar" ).mousemove(
        function( event ) {
            mouseX=event.pageX;
            mouseY=event.pageY;
            mouseMoved=1;
        }
    );

    // Get a reference to the last interval, then clean all
    var interval_id = window.setInterval("", 9999); 
    for (var i = 1; i < interval_id; i++)
        window.clearInterval(i);

    var interval = window.setInterval(
        function () {
            if (mouseMoved==0) return;
            if (mouseUpdate==1) return;
            mouseMoved=0;
            mouseUpdate=1;
            var text=getNearestDatetime();
            $('#position').text(text);
            mouseUpdate=0;
        }, 500
    );

}

function checkStudio(){
    if($('#studio_id').val()=='-1'){
        $("#no_studio_selected").dialog({
            modal: true,
            title: "please select a studio",
        });
        return 0;
    }
    return 1;
}

function show_not_assigned_to_series_dialog(){
    $("#event_no_series").dialog({
        resizable: false,
        width:800,
        height:340,
        modal: true,
        title: loc['label_event_not_assigned_to_series'],
        buttons: {
            Cancel: function() {
                $( this ).dialog( "close" );
            }
        }
    });
}

function show_schedule_series_dialog(project_id, studio_id, series_id, start_date){
    $("#series").dialog({
        resizable: false,
        width:800,
        height:340,
        modal: true,
        title: loc['label_schedule_series'],
        buttons: {
            "Schedule": function() {
                var series_id=$('#series_select').val();
                var duration=$('#series_duration').val();
                var start_date=$('#series_date').val();
                var url='series.cgi?project_id='+project_id+'&studio_id='+studio_id+'&series_id='+series_id+'&start='+escape(start_date)+'&duration='+duration+'&show_hint_to_add_schedule=1#tabs-schedule';
                load(url);
            },
            "Cancel" : function() {
                $( this ).dialog( "close" );
            }
        }
    });
}

function setDatePicker(){

    initRegions(region);
    
    registerDatePicker(
        '#start_date', {
            showWeek: true,
            onSelect : function(dateText, inst) {
                var url=setUrlParameter(window.location.href,'date',dateText);
                loadCalendar(url);    
            }
        }
    );
    
    var date=getUrlParameter("date");
    $('#start_date').datepicker("setDate", date);
}

// add name=value to current url
function getUrl(name,value){
    var url=window.location.href;
    url=updateUrlParameters(url);
    if((name!=null)&&(value!=null)){
        url=setUrlParameter(url, name, value);
    }
    return url;
}

// to be called from elements directly
function reloadCalendar(){
    var url=window.location.href;
    url=updateUrlParameters(url);
    loadCalendar(url);
}

function initTodayButton(){
    $('button#setToday').on('mousedown', function(event){
        var url=window.location.href;
        url=updateUrlParameters(url);
        url=removeUrlParameter(url, 'date');
        if (event.which==leftMouseButton){
            loadCalendar(url);
        }
        if (event.which==middleMouseButton){
            openNewTab(url);
        }
    })
    return true;
}

function initSelectDate(){
    $('#selectDate').on('click', function(){
        if($('#ui-datepicker-div').css("display")=="block"){
            $('#start_date').datepicker("hide");
        }else{
            $('#start_date').datepicker("show");
        }
    });
}

function initCalendarMenu(){
    //add filters to header
    var html='';
    html += '<div><input id="show_events"   type="checkbox" checked="checked">'+(label_events || "label") +'</div>';
    html += '<div><input id="show_schedule" type="checkbox" checked="checked">'+(label_schedule || "schedule")+'</div>';
    html += '<div><input id="show_playout"  type="checkbox" checked="checked">'+(label_playout || "playout")+'</div>';
    html += '<div><input id="show_worktime" type="checkbox" >'+(label_worktime || "worktime")+'</div>';
    $('#toolbar').append(html);

    if(getUrlParameter('s')=='0') unselectCheckbox('#show_schedule');
    if(getUrlParameter('e')=='0') unselectCheckbox('#show_events'  );
    if(getUrlParameter('p')=='0') unselectCheckbox('#show_playout' );
    if(getUrlParameter('w')=='0') unselectCheckbox('#show_worktime');

    setSelectedOptions();
    setFilter();
    setDatePicker();
    initTodayButton();
    initSelectDate();
    resizeCalendarMenu();
}

function createId(prefix) {
  function s4() {
    return Math.floor((1 + Math.random()) * 0x10000)
      .toString(16)
      .substring(1);
  }
  return prefix+'_'+s4() + s4();
}

function showRmsPlot(id, project_id, studio_id, start){
    console.log(id+" "+project_id+" "+studio_id+" "+start)
    $('#'+id).dialog({
        width:940, 
        height:560,
        open: function () {
            $(this).scrollTop(0);
        }        
    });
    return false;
}

function deleteFromPlayout(id, projectId, studioId, start){
    var url='playout.cgi';
    url+='?action=delete';
    url+='&project_id='+escape(projectId);
    url+='&studio_id='+escape(studioId);
    url+='&start_date='+escape(start);
    $('#'+id).load(url);
    return false;
}

function quoteAttr(attr){
    return "'"+attr+"'";
}

function initRmsPlot(){
    $( "#calendar div.play" ).hover(
        function() {
            var plot        = $(this).attr("rms");
            var id          = $(this).attr("id");
            var field       = id.split('_');
            var classname   = field.shift();
            var project_id  = field.shift();
            var studio_id   = field.shift();
            var start       = $(this).attr("start")
            
            if (project_id==null) return;
            if (studio_id==null) return;
            if (start==null) return;

            if ( !$(this).hasClass("clickHandler") ){
                $(this).addClass("clickHandler");
                $(this).click( function(event){
                     event.stopImmediatePropagation();
                     showRmsPlot( id , project_id , studio_id , start );
                });
            }

            if ( (!$(this).hasClass("rms_image")) && (plot!=null)){
                $(this).addClass("rms_image");

                var content = $(this).html();
                var id      = createId("rms_img");
                var url     = '/agenda_files/playout/'+plot;
                var img     = '<img src="'+url+'" ></img>';
                var deleteHandler = 'onclick="deleteFromPlayout(' + quoteAttr(id) + ", " + quoteAttr(project_id) + ", " + quoteAttr(studio_id) + ", "+ quoteAttr(start) + ')"';

                var details='';
                details += '<div id="'+id+'" class="rms_detail" style="display:none">';
                details += '<div class="image">'+img+'</div>';
                details += '<div class="text">'+content+'</div>';
                if (start!=null) details += '<button '+deleteHandler+'>delete</button>';
                details += "</div>";
                $(this).append(img + details);
            }

            $(this).find('img').each(function(){
                $(this).show();
            });
            
        }, 
        function() {
            var plot=$(this).attr("rms");
            if (plot==null) return;
            $(this).find('img').hide();
        }
    );
}

function loadCalendarList(){
    var url=window.location.href;
    url=updateUrlParameters(url);
    updateTable();
    updateUrls(url);
}

function loadCalendar(url, mouseButton){

    // open calendar in new tab on middle mouse button
    if ( (mouseButton!=null) && (mouseButton==middleMouseButton) ){
        url=window.location.href;
        url=updateUrlParameters(url);
        openNewTab(url);
        return true;
    }

    $('#calendarTable').css('opacity','0.3');
    if (url==null) {
        url=window.location.href;
        url=updateUrlParameters(url);
    }
    url=setUrlParameter(url, 'part', '1');
    updateContainer('calendarTable', url, function(){ 
        updateTable(); 
        $('#calendarTable').css('opacity','1.0');
        $('#current_date').html(current_date);
        updateUrls(url);
        initRmsPlot();
        adjustColors();
    });
}

function updateTable(){

    $('#previous_month').off();
    $('#previous_month').on('mouseup', function(event){
        var url=getUrl('date', previous_date);
        if (event.which==leftMouseButton){
            loadCalendar(url);
        }
        if (event.which==middleMouseButton){
            openNewTab(url);
        }
    });

    $('#next_month').off();
    $('#next_month').on('mouseup', function(event){
        var url=getUrl('date', next_date);
        if (event.which==leftMouseButton){
            loadCalendar(url);
        }
        if (event.which==middleMouseButton){
            openNewTab(url);
        }
    });
    
    var baseElement='#event_list';
    if(calendarTable==1){
        baseElement='#calendar';
        resizeCalendarMenu();

        $(window).resize(function() {
            resizeCalendarMenu();
            setupMenu()
        });
    }

    show_schedule();
    show_events();
    show_playout();
    show_worktime();
    
    $('#show_events').off();
    $('#show_events').on("click",   
        function(){
            show_events();
            updateUrls();
        }
    );
    $('#show_schedule').off();
    $('#show_schedule').on("click",   
        function(){
            show_schedule();
            updateUrls();
        }
    );
    $('#show_playout').off();
    $('#show_playout').on("click",
        function(){
            show_playout();
            updateUrls();
        }
    );
    $('#show_worktime').off();
    $('#show_worktime').on("click",
        function(){
            show_worktime();
            if(isChecked('#show_worktime')){
                unselectCheckbox('#show_events');
                unselectCheckbox('#show_schedule');
                unselectCheckbox('#show_playout');
            }else{
                selectCheckbox('#show_events');
                selectCheckbox('#show_schedule');
                selectCheckbox('#show_playout');
            }
            show_events();
            show_schedule();            
            show_playout();            
            updateUrls();
        }
    );

    //disable context menu
    document.oncontextmenu = function() {return false;};

    //edit existing event
    $(baseElement).off();
    $(baseElement).on("mousedown", ".event", function(event){
        handleEvent($(this).attr("id"), event);
    });

    //create series or assign to event
    $(baseElement).on("click", ".event.no_series", function(){
        handleUnassignedEvent($(this).attr("id"));
    });

    $(baseElement).on("mousedown", ".schedule", function(event){
        if ( $('.ui-draggable-dragging').length>0 ) return;
        handleSchedule($(this).attr("id"), $(this).attr("start"), event);
    });

    //create schedule within studio timeslots
    $(baseElement).on("click", ".grid", function(){
        handleGrid($(this).attr("id"));
    });

    // edit work schedule
    $(baseElement).on("mousedown", ".work", function(event){
        handleWorktime($(this).attr("id"), event);
    });
    

    //add tooltips
    $('#calendarTable').tooltip({
        items:'td div,img',
        show: {
            effect: "none",
            delay: 500
        },
        hide: {
            effect: "none",
            delay: 500
        },
        close: function(){
            $('.ui-helper-hidden-accessible').children().first().remove();
        },
        content: function(){
            var elem=$(this);
            if (elem.attr('title')!=null) return elem.attr('title');
            if (elem.hasClass('event') || elem.parent().hasClass('event'))
                return 'click to edit show'
            if (elem.hasClass('schedule') || elem.parent().hasClass('schedule'))
                return 'click to create show'
            if (elem.hasClass('no_series') || elem.parent().hasClass('no_series'))
                return 'please create a series for this show'
            if (elem.hasClass('work') || elem.parent().hasClass('work'))
                return 'edit work schedule'
            if (elem.hasClass('grid') || elem.parent().hasClass('grid'))
                return 'click to create schedule'
        }
    });
    
    if($('#event_list table').length!=0){
        $('#event_list table').tablesorter({
            widgets: ["filter"],
            usNumberFormat : false
        });
    }

    $('#editSeries').on("click",
        function(){
            // get first event_list item
            var id = $('#event_list tbody tr').first().attr('id');
            var field=id.split('_');
            var classname   =field.shift();
            var project_id  =field.shift();
            var studio_id   =field.shift();
            var series_id   =field.shift();
            var url='series.cgi';
            url+='?project_id='+project_id;
            url+='&studio_id='+studio_id;
            url+='&series_id='+series_id;
            url+='&action=show';
            load(url);
        }
    );

    //set checkboxes from url parameters and update all urls
    $('#calendar').show();

    showMouse();
}

function addDraggable(){
    var height=$('#calendar div.time').first().outerHeight()/12;

    $("#calendar div.schedule").draggable({ 
        containment: "parent",
        axis: "y",
        grid: [height, height],
        cursorAt: { top: 0 },
        drag: function(){
            $(this).parent().children(".schedule").each(
                function(key, value){
                    if ( isColliding($(this)) == true ){ 
                        $(this).addClass("error");
                        $(this).addClass("x2");
                    }else{ 
                        $(this).removeClass("error");
                        $(this).addClass("x2");
                    }
                }
            );
        },
        stop: function() {
            console.log("move to "+$("#position").text());
        }
    });

}

var dragged=null;
function isColliding(div){
    dragged=div;
    var intersect=false;
    div.parent().children(".schedule").each(
        function(key, value){
            if (dragged.is($(this))) {
                return;
            }
            if (collision(dragged, $(this))==true){
                intersect=true;
            }
        }
    );
    return intersect;
}

function collision(div1, div2) {
    var y1 = div1.offset().top;
    var h1 = div1.outerHeight(true);
    var b1 = y1 + h1;

    var y2 = div2.offset().top;
    var h2 = div2.outerHeight(true);
    var b2 = y2 + h2;

    var tolerate=6;
    if (b1 - tolerate < y2) return false;
    if (b2 - tolerate < y1) return false;
    return true;
}

function handleEvent(id, event){
    var field=id.split('_');
    var classname   =field.shift();
    var project_id  =field.shift();
    var studio_id   =field.shift();
    var series_id   =field.shift();
    var event_id    =field.shift();

    if (project_id<0) {alert("please select a project");return;}
    if (studio_id <0) {alert("please select a studio");return;}
    if (series_id <0) return;
    if (event_id  <0) return;

    var url="event.cgi?action=edit&project_id="+project_id+"&studio_id="+studio_id+"&series_id="+series_id+"&event_id="+event_id;
    if(event.which==1){
        load(url);
    }
    if(event.which==2){
        openNewTab(url);
    }
}

function handleUnassignedEvent(id){
    var field=id.split('_');
    var classname   =field.shift();
    var project_id  =field.shift();
    var studio_id   =field.shift();
    var series_id   =field.shift();
    var event_id    =field.shift();

    if(checkStudio()==0)return;
    if (project_id<0)   return;
    if (studio_id<0)    return;
    if (event_id<0)     return;
    $('#assign_series_events input[name="event_id"]').attr('value',event_id);

    show_not_assigned_to_series_dialog();
}

function handleSchedule(id, start_date, event){
    var field=id.split('_');
    var classname   =field.shift();
    var project_id  =field.shift();
    var studio_id   =field.shift();
    var series_id   =field.shift();

    if(checkStudio()==0)return;
    if (project_id<0)   return;
    if (studio_id<0)    return;
    if (series_id<0)    return;

    if(event.which==1){
        //left click: create event from schedule
        var url="event.cgi?action=show_new_event_from_schedule&project_id="+project_id+"&studio_id="+studio_id+"&series_id="+series_id+"&start_date="+start_date;
        load(url);
    }
    if(event.which==3){
        //right click: remove schedule
        var url='series.cgi?project_id='+project_id+'&studio_id='+studio_id+'&series_id='+series_id+'&start='+escape(start_date)+'&exclude=1&show_hint_to_add_schedule=1#tabs-schedule';
        load(url);
    }
}

function handleGrid(id){
    var field=id.split('_');
    var classname   =field.shift();
    var project_id  =field.shift();
    var studio_id   =field.shift();
    var series_id   =field.shift();//to be selected

    if(checkStudio()==0)return;
    if (project_id<0)   return;
    if (studio_id<0)    return;

    var start_date=getNearestDatetime();
    $('#series_date').attr('value',start_date);
    showDateTimePicker('#series_date');

    show_schedule_series_dialog(project_id, studio_id, series_id, start_date);
}

function handleWorktime(id, event){
    var field=id.split('_');
    var classname   =field.shift();
    var project_id  =field.shift();
    var studio_id   =field.shift();
    var schedule_id =field.shift();

    if(checkStudio()==0)return;
    if (project_id<0)   return;
    if (studio_id<0)    return;
    if (schedule_id<0)  return;
    var start_date=$(this).attr("start");

    var url="work-time.cgi?action=show_new_event_from_schedule&project_id="+project_id+"&studio_id="+studio_id+"&schedule_id="+schedule_id+"&start_date="+start_date;
    if(event.which==1){
        load(url);
    }
    if(event.which==2){
        openNewTab(url)
    }
}


function hexToRgbA(hex){
    var c;
    if(/^#([A-Fa-f0-9]{3}){1,2}$/.test(hex)){
        c= hex.substring(1).split('');
        if(c.length== 3){
            c= [c[0], c[0], c[1], c[1], c[2], c[2]];
        }
        c= '0x'+c.join('');
        return 'rgba('+[(c>>16)&255, (c>>8)&255, c&255].join(',')+',1)';
    }
    throw new Error('Bad Hex');
}

function adjustColors(){
    var elem = $('.schedule').get(0);
    var color1=window.getComputedStyle(elem).backgroundColor;
    var color2=color1.replace('rgb','rgba').replace(')',', 0.4)')
    $('.schedule').css('background', 'repeating-linear-gradient(to right, '+color1+', '+color1+' 1px, '+color2+' 1px, '+color2+' 2px) ');
}

$(document).ready(function(){
    initCalendarMenu();

    if(calendarTable==1){
        loadCalendar();
    }else{
        loadCalendarList();
    }

});

