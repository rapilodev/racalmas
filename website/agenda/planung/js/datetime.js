
// wrapper for date time picker with callback function
function showDateTimePicker(selector, options){
    $(selector).each( function(){
        // init on first select
        $(this).on('click', function(){
            if ($(this).hasClass("hasDatepicker")) return;

            var defaultOptions={
                dateFormat: "yy-mm-dd",
                timeFormat: "HH:mm",
                stepMinute: 5,
                firstDay: 1,
                showOtherMonths: true,
                selectOtherMonths: true,
                changeMonth: true,
                changeYear: true,
                showWeek: true,         
            }

            //recursively merge options
            $.extend(true, defaultOptions, options); 

            $(this).datetimepicker(defaultOptions);

            // set date and time from input field
            var datetime=$(this).attr('value');
            if ((datetime != null) && (datetime != "")){
                var datetime=parseDateTime(datetime);
                $(this).datetimepicker('setDate', datetime);
                $(this).datetimepicker('setTime', datetime);
            }

            if((region !=null) && (region !='' ) && (region != 'en')){
                $(this).datetimepicker( $.timepicker.regional[ region+"" ] );
            }
            //show if has been initialized on first click            
            $(this).focus();
        });
    });
}

// show date picker on first select with callback function
function showDatePicker(selector, options){

    $(selector).each( function(){
        // init on first select
        var activator=$(this);
        if ((options!=null)&&(options.activator!=null)) activator=$(options.activator);
        
        activator.on('click', function(){
            if ($(this).hasClass("hasDatepicker")) return;

            var defaultOptions={
                dateFormat: "yy-mm-dd",
                timeFormat: "HH:mm",
                showTimePicker: false,
                firstDay: 1,
                showOtherMonths: true,
                selectOtherMonths: true,        
                changeMonth: true,
                changeYear: true,        
                showWeek: true,         
            }

            //recursively merge options
            $.extend(true, defaultOptions, options); 
            $(this).datepicker(defaultOptions);

            // set date from input field
            var datetime=$(this).attr('value');
            if ((datetime != null) && (datetime != "")){
               $(this).datepicker('setDate', datetime);
            }

            if((region !=null) && (region !='' ) && (region != 'en')){
               $(this).datepicker( $.datepicker.regional[ region+"" ] );
            }
            //show if has been initialized on first click
            $(this).focus();
        });
    });
}

// date picker with direct registration
function registerDatePicker(selector, options){

    $(selector).each( function(){
        var defaultOptions={
            dateFormat: "yy-mm-dd",
            timeFormat: "HH:mm",
            showTimePicker: false,
            firstDay: 1,
            showOtherMonths: true,
            selectOtherMonths: true,        
            changeMonth: true,
            changeYear: true,        
            showWeek: true,         
        }

        //recursively merge options
        $.extend(true, defaultOptions, options); 
        $(this).datepicker(defaultOptions);

        // set date from input field
        var datetime=$(this).attr('value');
        if ((datetime != null) && (datetime != "")){
           $(this).datepicker('setDate', datetime);
        }

        if((region !=null) && (region !='' ) && (region != 'en')){
           $(this).datepicker( $.datepicker.regional[ region+"" ] );
        }
        //show if has been initialized on first click
        $(this).focus();
    });
}

function showYearPicker(selector, options){
    $(selector).each( function(){
        var year=new Date().getYear()+1900;
        var html='<select>';
        for (var i=year-10; i<year+10; i++){
            var selected='';
            if (i==year) selected=' selected="selected"';
            html+='<option value="'+i+'"'+selected+'>'+i+'</option>';
        }
        html+='</select>';
        $(selector).html(html);
        if (options.onSelect != null){
            $(selector+' select').on('change', options.onSelect);
        };
    })
}


function parseDateTime(datetime){
    var dateTime = datetime.split(/[ T]+/);

    var date = dateTime[0].split("-");
    var yyyy = date[0];
    var mm = date[1]-1;
    var dd = date[2];

    var h=0;
    var m=0;
    var s=0;
    if (dateTime.length>1){
        var time = dateTime[1].split(":");
        h = time[0];
        m = time[1];
        s = 0;
    }

    return new Date(yyyy,mm,dd,h,m,s);
}

function formatDateTime(datetime){
    var string= 1900+datetime.getYear()+'-';
    if (datetime.getMonth()<10)  { string+='0'+(datetime.getMonth()+1)  } else {string+=(datetime.getMonth()+1) };
    string+='-'
    if (datetime.getDate()<10)   { string+='0'+datetime.getDate()    } else {string+=datetime.getDate()    };
    string+=' '
    if (datetime.getHours()<10)  { string+='0'+datetime.getHours()  } else {string+=datetime.getHours()  };
    string+=':'
    if (datetime.getMinutes()<10){ string+='0'+datetime.getMinutes()} else {string+=datetime.getMinutes()};
    return string;
}

function formatDate(datetime){
    var string= 1900+datetime.getYear()+'-';
    if (datetime.getMonth()<9)  { string+='0'+(datetime.getMonth()+1)  } else {string+=(datetime.getMonth()+1) };
    string+='-'
    if (datetime.getDate()<10)   { string+='0'+datetime.getDate()    } else {string+=datetime.getDate()    };
    return string;
}

function formatTime(datetime){
    var string= '';
    if (datetime.getHours()<10)  { string+='0'+datetime.getHours()  } else {string+=datetime.getHours()  };
    string+=':'
    if (datetime.getMinutes()<10){ string+='0'+datetime.getMinutes()} else {string+=datetime.getMinutes()};
    return string;
}

//todo: separate weekday and formating
function addMinutes(datetime, minutes){
    var startDate=parseDateTime(datetime);
    var endDate=new Date(startDate.getTime()+minutes*60*1000);
    var weekday=getWeekday(endDate);
    var formatedDate=weekday+" "+formatDateTime(endDate);
    return formatedDate;
}

function addHours(datetime, hours){
    var startDate=parseDateTime(datetime);
    var endDate=new Date(startDate.getTime()+hours*60*60*1000);
    return endDate;
}

function addDays(datetime, days){
    var startDate=parseDateTime(datetime);
    var endDate=new Date(startDate.getTime()+days*24*60*60*1000);
    return endDate;
}

var weekdays=['Mo','Di','Mi','Do','Fr','Sa','So'];

function getWeekday(date){
    if (loc['weekday_Mo']!=null) weekdays[0]=loc['weekday_Mo'];
    if (loc['weekday_Tu']!=null) weekdays[1]=loc['weekday_Tu'];
    if (loc['weekday_We']!=null) weekdays[2]=loc['weekday_We'];
    if (loc['weekday_Th']!=null) weekdays[3]=loc['weekday_Th'];
    if (loc['weekday_Fr']!=null) weekdays[4]=loc['weekday_Fr'];
    if (loc['weekday_Sa']!=null) weekdays[5]=loc['weekday_Sa'];
    if (loc['weekday_Su']!=null) weekdays[6]=loc['weekday_Su'];
    //console.log(weekdays);

    return weekdays[(date.getDay()-1+7)%7]+','
}


