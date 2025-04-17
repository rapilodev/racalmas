"use strict";

// set checkbox values checked depending on value
function initCheckBoxes() {
    $('div.editor input[type="checkbox"]').each(
        function() {
            if ($(this).attr('value') == '1') {
                $(this).attr('value', '1');
                $(this).attr('checked', 'checked');
            } else {
                $(this).attr('value', '0');
                $(this).attr('checked', null);
            }
        }
    );
}

// add checkbox handler to change value on click
function addCheckBoxHandler() {
    $('div.editor input[type="checkbox"]').click(
        function() {
            if ($(this).attr('value') == '1') {
                $(this).attr('value', '0');
            } else {
                $(this).attr('value', '1');
            }
        }
    );
}

// show/hide series member edit
function edit_series_members(series_id) {
    $('.edit_series_members_' + series_id).toggle();
}

// show/hide schedule fields depending on period type for a given schedule element
function showScheduleFields(id) {
    var select = '#' + id + ' select[name="period_type"]';
    var type = $(select).val();
    //hide and show values for different schedule types
    if (type == 'single') {
        $('#' + id + ' div.cell.frequency').hide();
        $('#' + id + ' div.cell.end').hide();
        $('#' + id + ' div.cell.schedule_weekday').hide();
        $('#' + id + ' div.cell.week_of_month').hide();
        $('#' + id + ' div.cell.schedule_month').hide();
        $('#' + id + ' div.cell.nextDay').hide();
    } else if (type == 'days') {
        $('#' + id + ' div.cell.frequency').show();
        $('#' + id + ' div.cell.end').show();
        $('#' + id + ' div.cell.schedule_weekday').hide();
        $('#' + id + ' div.cell.week_of_month').hide();
        $('#' + id + ' div.cell.schedule_month').hide();
        $('#' + id + ' div.cell.nextDay').hide();
    } else if (type == 'week_of_month') {
        $('#' + id + ' div.cell.frequency').hide();
        $('#' + id + ' div.cell.end').show();
        $('#' + id + ' div.cell.schedule_weekday').show();
        $('#' + id + ' div.cell.week_of_month').show();
        $('#' + id + ' div.cell.schedule_month').show();
        $('#' + id + ' div.cell.nextDay').show();
    }
}

// show/hide schedule fields for all schedules
function initScheduleFields() {
    $('div.row.schedule form').each(function() {
        var id = $(this).attr('id');
        if (contains(id, 'schedule_')) showScheduleFields(id);
    });
}

// preselect options in select boxes
function setSelectedOptions() {
    $('#tabs-schedule select').each(
        function() {
            var value = $(this).attr('value');
            if (value == null) return;
            if (value == '') return;
            $(this).children().each(
                function() {
                    if ($(this).attr('value') == value) {
                        $(this).attr('selected', 'selected');
                    }
                }
            );
        }
    );
}

function initSelectChangeHandler(selector, name, title) {
    $(selector).each(
        function() {
            //replace select by input, if no matching field
            var value = $(this).attr('value');

            //check if a child is selected
            var found = 0;
            $(this).children().each(function() {
                if (found == 1) return;
                if ($(this).attr('value') == value) {
                    found = 1;
                    $(this).attr('selected');
                } else {
                    $(this).removeAttr('selected');
                }
            });
            if (found == 1) {
                return;
            }

            // find option with empty value
            var loc = getLocalization();
            $(this).children().each(function() {
                if ($(this).attr('value') == '') {
                    // add selected option
                    $(this).parent().append('<option value="' + value + '" selected="1">' + value + ' Min</option>');
                    // add option to edit field
                    $(this).parent().append(
                        loc[title] + '<br>' + '<input name="' + name + '" value="' + value + '" class="' + name + '">'
                    );
                }
            });
            setInputWidth();
        }
    );
}

//add handler to replace select boxes by input fields if choosen value is empty
function addSelectChangeHandler(selector, name, title) {
    $(selector).each(
        function() {
            $(this).change(function() {
                var loc = getLocalization();
                if ($(this).val() == '') {
                    //replace select by input, copy value from select to input,
                    var value = $(this).attr('value');
                    $(this).parent().html(
                        loc[title] + '<br>'
                        + '<input name="' + name + '" value="' + value + '" class="' + name + '">'
                    );
                } else {
                    //set selected value to select
                    $(this).attr('value', $(this).val());
                }
                setInputWidth();
            });
        }
    );
}

// change create schedule button name (add/remove)
function updateScheduleButtonName() {
    var buttonChecked = $('#schedule_add input[name="exclude"]');
    var loc = getLocalization();
    if (buttonChecked.prop('checked')) {
        $('#addScheduleButton').text(loc['label_remove_schedule']);
    } else {
        $('#addScheduleButton').text(loc['label_add_schedule']);
    }
}

// set css class on parent div to add margin on input fields
function setInputWidth() {
    $('#content .editor div.cell input').each(function() {
        $(this).parent().addClass('containsInput');
        $(this).parent().removeClass('containsSelect');
    });
    $('#content .editor div.cell select').each(function() {
        $(this).parent().addClass('containsSelect');
        $(this).parent().removeClass('containsInput');
    });

    $('#content .editor div.cell select[name="period_type"]').each(function() {
        if ($(this).val() == 'single') {
            $(this).parent().addClass('isSingle');
            $(this).addClass('isSingle');
        } else {
            $(this).parent().removeClass('isSingle');
            $(this).removeClass('isSingle');
        }
    });
}

function checkExcerptField() {
    var elem = $('textarea[name="excerpt"]');
    if (elem.length == 0) return;
    var length = elem.val().length;
    if (length > 250) {
        $('#excerpt_too_long').show();
    } else {
        $('#excerpt_too_long').hide();
    }
}

function checkFields() {
    checkExcerptField();
    $('textarea[name="excerpt"]').on("keyup", function() {
        checkExcerptField();
    });
    }

async function addUser(form) {
    let response = await fetch("series.cgi?", {
        method: 'POST',
        cache: "no-store",
        body: new URLSearchParams({
            action: "add_user",
            project_id: form.find("input[name='project_id']").val(),
            studio_id: form.find("input[name='studio_id']").val(),
            series_id: form.find("input[name='series_id']").val(),
            user_id: form.find("select[name='user_id'] option").filter(':selected').val(),
        })
    });
    if(response.status!=200) showError(response.statusText);
    let json = await response.json();
    if (json.error) {
        showError(json.error);
        return;
    }
    showSeries(
        form.find("input[name='project_id']").val(),
        form.find("input[name='studio_id']").val(),
        form.find("input[name='series_id']").val(),
        "#tabs-members"
    );
    showInfo("User added");
}

function commitRemoveUser(project_id, studio_id, series_id, user_id) {
    let dialog = commitAction(
        '<TMPL_VAR .loc.button_remove_member escape=js>',
        async function(){
            let response = await fetch("series.cgi?", {
                method: 'POST',
                cache: "no-store",
                body: new URLSearchParams({
                    action: "remove_user",
                    project_id: project_id,
                    studio_id: studio_id,
                    series_id: series_id,
                    user_id: user_id,
                })
            });
            let json = await response.json();
            if (json.error) {
                showError(json.error);
                return;
            }
            showInfo("User removed");
            $('tr#edit_series_members_' + user_id).remove();
            dialog.remove();
        }
    );
}

function commitDeleteSeries(project_id, studio_id, series_id) {
    commitAction( '<TMPL_VAR .loc.button_remove_series escape=js>',
        async function(){
            let response = await fetch("series.cgi?", {
                method: 'POST',
                body: new URLSearchParams({
                    action: "delete_series",
                    project_id: project_id,
                    studio_id: studio_id,
                    series_id: series_id,
                })
            });
            console.log(response)
            let json = await response.json();
            if (json.error) {
                showError(json.error);
                return;
            }
            showInfo("Series removed");
        }
    );
}

function showSeries(project_id, studio_id, series_id, tab) {
    loadUrl( "series.cgi?" + new URLSearchParams({
        action: "show_series",
        project_id: project_id,
        studio_id: studio_id,
        series_id: series_id,
    }).toString() + tab);
}

async function saveSchedule(form) {
    var formData = new FormData(form.get(0));
    formData.append("action", "save_schedule");
    let response = await fetch("series.cgi?",{
        method: 'POST',
        cache: "no-store",
        body: new URLSearchParams(formData)
    });
    if (response.status != 200) { showError(response.statusText); return }
    let json = await response.json();
    if (json.error) { showError(json.error); return;}
    console.log(json)
    showInfo("schedule saved");
    if (json.status == "schedule added") {
        showSeries(
            form.find("input[name='project_id']").val(),
            form.find("input[name='studio_id']").val(),
            form.find("input[name='series_id']").val(),
            '#tabs-schedule'
        );
    }
}

function deleteSchedule(form){
    commitAction('<TMPL_VAR .loc.button_delete_schedule escape=js>',
    async function () {
        var formData = new FormData(form.get(0));
        formData.append("action", "delete_schedule");
        let response = await fetch("series.cgi?",{
            method: 'POST',
            cache: "no-store",
            body: new URLSearchParams(formData)
        });
        if (response.status != 200) { showError(response.statusText); return }
        let json = await response.json();
        if (json.error) { showError(json.error); return;}
        showInfo("schedule deleted");
        showSeries(
            form.find("input[name='project_id']").val(),
            form.find("input[name='studio_id']").val(),
            form.find("input[name='series_id']").val(),
            '#tabs-schedule'
        );
    });
}

function listEvents(project_id, studio_id, series_id) {
    loadUrl('calendar.cgi?' + new URLSearchParams({
        project_id: project_id,
        studio_id: studio_id,
        series_id: series_id,
        list: 1,
    }).toString());
}

function showNewEvent(project_id, studio_id, series_id) {
    loadUrl('broadcast.cgi?' + new URLSearchParams({
        project_id: project_id,
        studio_id: studio_id,
        series_id: series_id,
        action: 'show_new_event',
    }).toString());
}


function showHistory(project_id, studio_id, series_id) {
    loadUrl('event-history.cgi?' + new URLSearchParams({
        project_id: project_id,
        studio_id: studio_id,
        series_id: series_id,
        action: 'show_new_event',
    }).toString());
}

async function rebuildEpisodes(project_id, studio_id, series_id) {
    let response = await fetch('series.cgi?' + new URLSearchParams({
        project_id: project_id,
        studio_id: studio_id,
        series_id: series_id,
        action: 'set_rebuild_episodes',
    }).toString(),{
        cache: "no-store",
    });
    let json = await response.json();
    if (json.error) {
        showError(json.error);
    } else {
        showInfo("episodes rebuit");
    }
}

async function previewRebuildEpisodes(project_id, studio_id, series_id) {

    let response = await fetch('series.cgi?' + new URLSearchParams({
        project_id: project_id,
        studio_id: studio_id,
        series_id: series_id,
        action: 'rebuild_episodes',
    }).toString(), {
        cache: "no-store"
    });
    let json = await response.json();
    if (json.error) {
        showError(json.error);
        return;
    }
    const doc = document.createElement("div");
    doc.setAttribute("class", "card");
    doc.setAttribute("id", "rebuild");

    var loc = getLocalization();
    const closeButton = document.createElement("button");
    closeButton.setAttribute("class", "right")
    closeButton.textContent = loc["button_close"];
    closeButton.setAttribute("onclick", '$("#rebuild").remove();$("#tabs").show();');
    doc.append(closeButton)

    $("#rebuild").remove();
    $("#tabs").hide();
    $("#tabs").after($(doc));
    if (json.result.changes > 0 && json.result.conflicts == 0) {
        const button = document.createElement("button");
        button.textContent = loc["button_commit"];
        button.setAttribute("onclick",
            ```rebuildEpisodes('$(project_id)','$(studio_id)','$(series_id)');return false;```
        );
        doc.append(button)
    }
    const table = document.createElement("table");
    const thead = document.createElement("thead");
    const tr = document.createElement("tr");
    for (let col of json.cols) {
        const td = document.createElement("td");
        td.textContent = col;
        tr.appendChild(td)
    }
    thead.appendChild(tr)
    table.appendChild(thead)
    doc.appendChild(table)

    const tbody = document.createElement("thead");
    table.appendChild(tbody)
    for (let row of json.rows) {
        const tr = document.createElement("tr");
        for (let col of json.cols) {
            const td = document.createElement("td");
            td.textContent = row[col];
            tr.appendChild(td)
        }
        tbody.appendChild(tr)
    }
}

$(document).ready(
    function() {
        loadLocalization();
        addBackButton();

        showDateTimePicker('input.datetimepicker.start')
        showDatePicker('input.datetimepicker.end');

        initCheckBoxes();
        addCheckBoxHandler();

        setTabs('#tabs');

        updateScheduleButtonName();
        initScheduleFields();
        setSelectedOptions();

        //if value is not selected in a option, replace select box by input field
        initSelectChangeHandler('#tabs-schedule .frequency select', 'frequency', 'frequency_days');
        addSelectChangeHandler('#tabs-schedule .frequency select', 'frequency', 'frequency_days');

        initSelectChangeHandler('#tabs-schedule .duration select', 'duration', 'duration_in_minutes');
        addSelectChangeHandler('#tabs-schedule .duration select', 'duration', 'duration_in_minutes');

        setInputWidth();
        checkFields();

        $('table#schedule_table').tablesorter({
            widgets: ["filter"],
            usNumberFormat: false
        });
    }
);
