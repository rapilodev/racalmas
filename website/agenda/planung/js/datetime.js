if (typeof window.namespace_datetime_js === 'undefined') { function namespace_datetime_js(){}
"use strict";

function showDateTimePicker(selector, options){
    var defaults = {
        locale: { firstDayOfWeek: 1, locale: "de"},
        enableTime: true,
        time_24hr: true,
        dateFormat: "Y-m-d H:i:S",
        altInput: true,
        altFormat: "D, j.n.Y H:i"
    }
    if (options){
        if (options["onSelect"]) defaults["onChange"] = options["onSelect"];
        if (options["onChange"]) defaults["onChange"] = options["onChange"];
    }
    var elem = $(selector).flatpickr(defaults);
    if (options && options.date) elem.setDate(options.date);
}

function showDatePicker(selector, options){
    var defaults = {
        locale: { firstDayOfWeek: 1, locale: "de" },
        altInput: true,
        altFormat: "D, j.n.Y",
    }
    if (options){
        if (options["onSelect"]) defaults["onChange"] = options["onSelect"];
        if (options["onChange"]) defaults["onChange"] = options["onChange"];
        if (options["wrap"]) defaults["wrap"] = options["wrap"];
    }
    return $(selector).flatpickr(defaults);
}

function showYearPicker(selector, options){
    $(selector).each( function(){
        var year=new Date().getFullYear();
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
    if (!datetime) return null;

    const [datePart, timePart] = datetime.split(/[ T]+/);
    const [y, m, d] = datePart.split('-').map(Number);
    if (!y || m < 1 || m > 12 || d < 1 || d > 31) return null;

    let h = 0, min = 0;
    if (timePart) {
        [h, min] = timePart.split(':').map(Number);
        if (h > 23 || min > 59) return null;
    }

    const dt = new Date(y, m - 1, d, h, min, 0);
    return isNaN(dt) ? null : dt;
}

function formatDate(date){
    if (!(date instanceof Date) || isNaN(date)) return '';    
    const year  = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, "0");
    const day   = String(date.getDate()).padStart(2, "0");
    return `${year}-${month}-${day}`;
}

function formatTime(datetime){
    var string= '';
    if (datetime.getHours()<10)  { string+='0'+datetime.getHours()  } else {string+=datetime.getHours()  };
    string+=':'
    if (datetime.getMinutes()<10){ string+='0'+datetime.getMinutes()} else {string+=datetime.getMinutes()};
    return string;
}

function formatLocalDate(date){
    const locale = navigator.language;
    return new Date(date).toLocaleDateString(locale, {
        dateStyle: "medium"
    });
}

// todo: 
function fmtDatetime(dateString, options = {}) {
    try {
        const date = new Date(dateString);
        const defaultOptions = {
            weekday: 'short',
            year: 'numeric',
            month: 'numeric',
            day: 'numeric',
            hour: 'numeric',
            minute: 'numeric',
            "hour12": false
        };
        const language = Intl.NumberFormat().resolvedOptions().locale;
        return new Intl.DateTimeFormat(language, { ...defaultOptions, ...options }).format(date);
    } catch (e) {
        console.log(e)
        showError(e)
    }
}

function fmtDate(dateString, options = {}) {
    try {
        const date = new Date(dateString);
        const defaultOptions = {
            weekday: 'short',
            year: 'numeric',
            month: 'numeric',
            day: 'numeric'
        };
        const mergedOptions = { ...defaultOptions, ...options };
        const language = Intl.NumberFormat().resolvedOptions().locale;
        return new Intl.DateTimeFormat(language, mergedOptions).format(date);
    } catch (e) {
        console.log(e)
        showError(e)
    }
}


//todo: separate weekday and formating
function addMinutes(datetime, minutes){
    var startDate=parseDateTime(datetime);
    if (!startDate) return null;
    return new Date(startDate.getTime()+minutes*60*1000);
}

function addHours(datetime, hours){
    var startDate=parseDateTime(datetime);
    if (!startDate) return null;
    var endDate=new Date(startDate.getTime()+hours*60*60*1000);
    return endDate;
}

function addDays(datetime, days){
    const d = datetime instanceof Date ? new Date(datetime) : parseDateTime(datetime);
    if (!d) return null;
    d.setDate(d.getDate() + days);
    return d;
}

function getWeekday(date){
    if (!date) return '?';
    var loc = getLocalization();
    var locale = loc.locale;
    return new Intl.DateTimeFormat(locale, { weekday: 'short' }).format(date) + ',';
}

//end of guard
}