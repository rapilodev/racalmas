// region will be set at template
// set datepicker and timepicker localization for given region
function initRegions(region){

    if (region == null) return;
    if (region == 'en') return;
    if ($.datepicker == null){
        console.log("datepicker not loaded")
        return;
    }
    $.datepicker.regional['de'] = {
	    closeText: 'Schließen',
	    prevText: '&#x3C;Zurück',
	    nextText: 'Vor&#x3E;',
	    currentText: 'Heute',
	    monthNames: ['Januar','Februar','März','April','Mai','Juni',
	    'Juli','August','September','Oktober','November','Dezember'],
	    monthNamesShort: ['Jan','Feb','Mär','Apr','Mai','Jun',
	    'Jul','Aug','Sep','Okt','Nov','Dez'],
	    dayNames: ['Sonntag','Montag','Dienstag','Mittwoch','Donnerstag','Freitag','Samstag'],
	    dayNamesShort: ['So','Mo','Di','Mi','Do','Fr','Sa'],
	    dayNamesMin: ['So','Mo','Di','Mi','Do','Fr','Sa'],
	    weekHeader: 'KW',
	    dateFormat: 'dd.mm.yy',
	    firstDay: 1,
	    isRTL: false,
	    showMonthAfterYear: false,
	    yearSuffix: ''
    };

    $.timepicker.regional['de'] = {
	    timeOnlyTitle: 'Zeit wählen',
	    timeText: 'Zeit',
	    hourText: 'Stunde',
	    minuteText: 'Minute',
	    secondText: 'Sekunde',
	    millisecText: 'Millisekunde',
	    timezoneText: 'Zeitzone',
	    currentText: 'Jetzt',
	    closeText: 'Schließen',
	    timeFormat: 'HH:mm',
	    amNames: ['AM', 'A'],
	    pmNames: ['PM', 'P'],
	    isRTL: false
    };

    $.datepicker.setDefaults($.datepicker.regional[ region ]);
    $.timepicker.setDefaults($.timepicker.regional[ region ]);
}
