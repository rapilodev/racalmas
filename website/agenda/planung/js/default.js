if (window.namespace_default_js) throw "stop"; window.namespace_default_js = true;
"use strict";

// <sprite-icon name="help"> support
if (!customElements.get('sprite-icon')) {
    class SpriteIcon extends HTMLElement {
        static get observedAttributes() {
            return ['name'];
        }
    
        connectedCallback() {
            this.renderIcon();
        }
    
        attributeChangedCallback(attrName, oldValue, newValue) {
            if (attrName === 'name' && oldValue !== newValue) {
                this.renderIcon();
            }
        }
    
        renderIcon() {
            const iconName = this.getAttribute('name');
            if (!iconName) return;
            this.innerHTML = '';
            const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
            svg.setAttribute('role', 'img');
            svg.setAttribute('aria-hidden', 'true');
            if (this.className) svg.setAttribute('class', this.className);
            const use = document.createElementNS('http://www.w3.org/2000/svg', 'use');
            use.setAttributeNS('http://www.w3.org/1999/xlink', 'href', `icons/sprite.svg#icon-bright-${iconName}`);
            svg.appendChild(use);
            this.appendChild(svg);
        }
    }
    customElements.define('sprite-icon', SpriteIcon);
}

function getController() {
    var url = window.location.href;
    var parts = url.split('.cgi');
    url = parts[0];
    parts = url.split('/');
    var usecase = parts[parts.length - 1];
    return usecase;
}

function openNewTab(url) {
    window.open(url, '_blank');
}

function set_studio(id) {
    var url = window.location.href;
    //split by #
    var comment = url.split(/\#/);
    url = comment.shift();
    comment = comment.join('#');
    //split by ?
    var parts = url.split(/\?/);
    url = parts.shift();
    //split by &
    parts = parts.join('?').split(/\&+/);
    var params = [];
    if (parts.length > 0) {
        for (index in parts) {
            //add all name value pairs but studio id
            var pair = parts[index];
            if (!pair.match(/^studio_id=/)) params.push(pair);
        }
    }
    //add studio id
    if (id == null) id = -1;
    if (id == '') id = -1;
    params.push('studio_id=' + id);
    //append parameters to url
    url += '?' + params.join('&');
    if ((comment != null) && (comment != '')) url += '#' + comment;
    window.location = url;
}

function set_project(id) {
    var url = window.location.href;
    //split by #
    var comment = url.split(/\#/);
    url = comment.shift();
    comment = comment.join('#');
    //split by ?
    var parts = url.split(/\?/);
    url = parts.shift();
    //split by &
    parts = parts.join('?').split(/\&+/);
    var params = [];
    if (parts.length > 0) {
        for (index in parts) {
            //add all name value pairs but project id
            var pair = parts[index];
            if (
                (!pair.match(/^project_id=/))
                && (!pair.match(/^studio_id=/))
            ) params.push(pair);
        }
    }
    //add project id
    if (id == null) id = -1;
    if (id == '') id = -1;
    params.push('project_id=' + id);
    //append parameters to url
    url += '?' + params.join('&');
    if ((comment != null) && (comment != '')) url += '#' + comment;
    window.location = url;
}

function contains(s, t) {
    if (s == false) return false;
    if (t == false) return false;
    if (s == null) return false;
    return s.indexOf(t) != -1;
}

function element(tag, params) {
    return Object.assign(document.createElement(tag), params);
}

function button({ id, text, onClick, title = "" }) {
    var button = element("button", {
        id, textContent: text, className: "button", title
    });
    button.addEventListener("click", onClick);
    return button;
}

function icon(project_id, studio_id, filename) {
    return element('img', {
        id: "imagePreview",
        src: `show-image.cgi?project_id=${project_id}&studio_id=${studio_id}&filename=${filename}&type=icon`
    });
}

function set_breadcrumb(s) {
    document.getElementById('breadcrumb').innerHTML = s;
    document.title = s;    
}

function showError(s) {
    console.log("showError: "+s);
    if ($('#error').length) {
        $('#error').html(s);
    } else {
        showToast(s, { color: "white", background: "red", duration: 30000 })
    }
}

function showInfo(s) {
    if ($('#info').length) {
        $('#info').html(s);
    } else {
        showToast(s, { color: "white", background: "green" })
    }
}

function showWarn(s) {
    if ($('#warn').length) {
        $('#warn').html(s);
    } else {
        showToast(s, { color: "black", background: "yellow" })
    }
}

function showToast(s, options) {
    console.log("showToast", s)
    $('#toast').remove();
    let duration = options.duration || 1000;
    let color = options.color || "#000";
    let background = options.background || '#ccc';
    $('body').append("<div class='toast' id='toast'>" + s + "</div>");
    $('#toast').hide().css({
        "color": color,
        "background": background,
    }).fadeIn();
    $('#toast').on("click", () => $('#toast').remove());
    setTimeout(function() {
        $('#toast').fadeOut(
            () => $('#toast').remove()
        );
    }, duration);
}

function loadCss(url) {
    let link = document.createElement('link');
    link.rel = 'stylesheet';
    link.href = url;
    document.head.appendChild(link);
}

async function updateContainer(id, url, callback) {
    console.log(url);
    if (!id) throw Error(`id is null`);
    var target = id == 'body' ? document.body : document.getElementById(id);
    if (!target) throw Error(`updateContainer: element with id ${id} no found`);
    console.log($("#id"));
    let response = await fetch(url, { "cache": "no-store" });
    if (!response.headers.has("content-type")) {
        showError("No content type");
        console.error(response);
        return;
    }
    if (response.status != 200) return showError(response.statusText);
    let type = response.headers.get("content-type").split(";")[0];
    if (type == "text/html") {
        console.log("html")
        target.innerHTML = await response.text();
        // load scripts from response
        /*
        target.querySelectorAll('script').forEach(script => {
            const newScript = document.createElement('script');
            newScript.text = script.textContent;
            Array.from(script.attributes).forEach(attr => {
                newScript.setAttribute(attr.name, attr.value);
            });
            script.parentNode.replaceChild(newScript, script);
            console.log("load_script " + newScript.src);
        });
        */
        if (callback != null) callback();
    } else if (type == "application/json") {
        let json = await response.json();
        showError(json.error);
    }
    return target;
}

function loadUrl(uri) {
    if (uri.startsWith("/")) {
        // relative to base
        uri = window.location.origin + uri;
    } else if (!uri.startsWith("http")) {
        // relative to directory
        var path = window.location.pathname.replace(/\/$/, "");
        path = path.split("/");
        path.pop();
        uri = window.location.origin + path.join("/") + "/" + uri;
    }
    var url = new URL(uri);
    url.searchParams.append("_", Date.now());
    window.location = url;
    $('body').css('cursor', 'wait');
}


function missing(...args) {
    if (args.filter(v => v).length == args.length) return false;
    showError("Missing param");
    return true;
}

async function fetchJson(url, options = {}) {
    const {
        method = 'GET',
        params = null,
        headers = {},
        showErrors = true
    } = options;
    
    try {
        const fetchOptions = {
            method: method.toUpperCase(),
            cache: "no-store",
            headers: {
                "accept": 'application/json',
                ...headers
            }
        };
        
        // Handle URL params for GET/DELETE or body for POST/PUT/PATCH
        if (['GET', 'HEAD', 'DELETE'].includes(fetchOptions.method)) {
            // Add params to URL
            if (params) {
                const searchParams = new URLSearchParams(params);
                url += (url.includes('?') ? '&' : '?') + searchParams.toString();
            }
        } else {
            // Add body for POST/PUT/PATCH
            if (params) {
                // Check if params is FormData or plain object
                if (params instanceof FormData) {
                    fetchOptions.body = new URLSearchParams(params);
                } else if (typeof params === 'object') {
                    fetchOptions.body = new URLSearchParams(params);
                } else {
                    fetchOptions.body = params;
                }
            }
        }
        console.log(["fetch",url, fetchOptions])
        const response = await fetch(url, fetchOptions);
        
        // Check content type
        const contentType = response.headers.get("content-type") || '';
        if (!contentType.startsWith("application/json")) {
            const error = new Error(`Invalid response type for ${url}`);
            error.type = 'INVALID_CONTENT_TYPE';
            throw error;
        }
        
        // Check authentication
        if (response.status === 401) {
            const error = new Error(loc.login_required);
            error.type = 'UNAUTHORIZED';
            throw error;
        }
        
        // Parse JSON
        let json;
        try {
            json = await response.json();
        } catch (e) {
            const error = new Error(`Invalid JSON response from ${url}`);
            error.type = 'INVALID_JSON';
            error.cause = e;
            throw error;
        }
        
        // Check application-level errors
        if (json.error) {
            const error = new Error(json.error);
            error.type = 'APPLICATION_ERROR';
            throw error;
        }
        
        // Check HTTP status
        if (!response.ok) {
            const error = new Error(response.statusText || `HTTP ${response.status}`);
            error.type = 'HTTP_ERROR';
            error.status = response.status;
            throw error;
        }
        
        return json;
        
    } catch (error) {
        if (showErrors) {
            showError(error.message);
        }
        console.error(`fetchJson [${method}] ${url}:`, error);
        return null;
    }
}

// Convenience wrappers
async function getJson(url, params = null, options = {}) {
    return fetchJson(url, { method: 'GET', params, ...options });
}

async function postJson(url, params = null, options = {}) {
    return fetchJson(url, { method: 'POST', params, ...options });
}

async function putJson(url, params = null, options = {}) {
    return fetchJson(url, { method: 'PUT', params, ...options });
}

async function deleteJson(url, params = null, options = {}) {
    return fetchJson(url, { method: 'DELETE', params, ...options });
}

async function patchJson(url, params = null, options = {}) {
    return fetchJson(url, { method: 'PATCH', params, ...options });
}
/*
async function getJson(url, params) {
    url += url.includes('?') ? '' : '?';
    if (params instanceof URLSearchParams) {
        url += params.toString();
    } else if (params && typeof params === 'object') {
        params = Object.fromEntries(Object.entries(params).filter(([_, v]) => v));
        if (Object.keys(params).length) url += new URLSearchParams(params).toString();
    }
    console.log("url:", url);
    let response = await fetch(url, {
        method: 'GET',
        cache: "no-store",
        headers: { "Accept": 'application/json' }
    });
    let contentType = response.headers.get("content-type") || '';
    if (!contentType.startsWith("application/json")) {
        showError("invalid response type for " + url);
        return null;
    }
    if (response.status == 401) {
        showError(loc.login_required);
        return null;
    }        
    let json;
    try{
        json = await response.json();
    } catch(e) {
        showError("Invalid JSON response from " + url);
        console.error("JSON parse error:", e);
        return null;        
    };
    
    if (json.error) {
        showError(json.error);
        return null;
    }        
    if (response.status !== 200) {
        showError(response.statusText);
        return null;
    }        
    return json;
}

async function postJson(url, params) {
    let response = await fetch(url, {
        method: 'POST',
        cache: "no-store",
        headers: { "accept": 'application/json' },
        body: new URLSearchParams(params)
    });
    if (
        (!response.headers.get("content-type") || '').startsWith("application/json")
    ) return showError("invalid response type for " + url);
    if (response.status == 401) return showError(loc.login_required);
    let json;
    try{ json = await response.json();} catch(e){}
    if (json.error) return showError(json.error);
    if (response.status !== 200) return showError(response.statusText);
    return json;
}
*/
function getFormValues(form, allowed) {
    return Object.fromEntries(
        new FormData(form).filter(
            ([name]) => allowed.includes(name)
        )
    )
}

function formToParams(form) {
    let params = new URLSearchParams();
    for (let pair of new FormData(form)) {
        params.append(pair[0], pair[1]);
    }
    return params;
}

// init getTextWidth
function initTextWidth() {
    if ($('#textWidth').length > 0) return;
    $('#content').append('<span id="textWidth" style="padding:0;margin:0;visibility:hidden; white-space:nowrap;"></span>')
}

// get width of selected text
function getTextWidth(s) {
    $("#textWidth").html(s);
    return $("#textWidth").width();
}

// check width of all selected elements and set width to max of it
function setTextWidth(select, minValue) {
    var maxWidth = minValue;
    $(select).each(
        function() {
            var width = getTextWidth($(this).val()) - 8;
            if (width > maxWidth) maxWidth = width;
        }
    );
    $(select).each(
        function() {
            $(this).css('width', maxWidth);
        }
    );
}

// trigger action on commit
function commitAction(title, action) {
    if (title == null) { alert("missing title"); return; }
    if (action == null) { alert("missing action"); return; }
    return showDialog({
        title: '<img src="image/dark/alert.svg">' + loc.ask_for_commit + '</p>',
        buttons: {
            OK: function() { action(); },
            Cancel: function() { $(this).closest('div#dialog').hide().remove(); }
        }
    });

}

function showDialog(options) {
    if ($("#dialog").length > 0) $("#dialog").remove();
    $("body").append(
        '<div id="dialog" class="panel">'
        + (options.title ? '<div id="title">' + options.title + '</div>' : '')
        + (options.content ? options.content : '')
        + '</div>'
    );
    var dialog = $('#dialog');
    if (options.width) dialog.css("width", options.width);
    if (options.height) dialog.css("height", options.height);
    if (options.buttons) {
        dialog.append('<div id="buttons">');
        let buttons = $('#dialog #buttons');
        Object.keys(options.buttons).forEach(function(key) {
            var value = options.buttons[key];
            buttons.append("<button>" + key + "</button");
            var button = $("#dialog button").last();
            button.on("click", value);
            button.addClass('dialog-' + key.toLowerCase().replace(/[^a-zA-Z0-9]/g, '-'))
        });
    }
    if (options.onOpen) options.onOpen();
    return dialog;
}

// set action=<action> at form and submit the form after confirmation
function commitForm(formElement, action, title, callback) {
    if (formElement == null) { alert("missing id"); return }
    if (action == null) { alert("missing action"); return }
    if (title == null) { alert("missing title"); return }
    formElement = '#' + formElement;
    if ($(formElement).length != 1) { alert("id " + formElement + " exists not only once, but " + $(formElement).length + " times"); return }
    if ($(formElement).is('form') == 0) { alert("id " + formElement + " this is not a form"); return }
    if (callback == null) {
        callback = function() {
            alert("trigger form submit (missing callback!)")
            $(formElement).append('<input type="hidden" name="action" value="' + action + '">');
            $(formElement).submit();
        }
    }
    commitAction(title, callback);
}

function setUrlParameter(url, name, value) {
    const u = new URL(url, window.location.href);
    u.searchParams.set(name, value);
    return u.toString();
}

function removeUrlParameter(url, name) {
    var r = new RegExp("[\\?]" + name + "=[^&#]*");
    url = url.replace(r, '?');
    var r = new RegExp("&" + name + "=[^&#]*");
    url = url.replace(r, '');
    return url;
}

function getUrlParameter(name) {
    const params = new URLSearchParams(window.location.search);
    return params.get(name);
}

function handleBars() {
    var menu = $('#calcms_nav');
    menu.toggleClass('mobile');
    if (menu.hasClass('mobile')) {
        $('#calcms_nav>div').show();
        $('#content').hide();
    } else {
        $('#content').show();
        setupMenu(1);
    }
}

var oldWidth = 0;
function setupMenu(update) {
    var xmax = 960;
    var menu = $('#calcms_nav');
    var width = menu.width();
    if ((width < xmax) && (oldWidth >= xmax)) update = 1;
    if ((width >= xmax) && (oldWidth < xmax)) update = 1;
    if (oldWidth == 0) update = 1;
    if (update == 1) {
        if (menu.width() < 960) {
            $('#calcms_nav>div').hide();
            $('#calcms_nav>div.mobile').show();
        } else {
            $('#calcms_nav>div').show();
            $('#calcms_nav #bars').hide();
            menu.removeClass('mobile');
        }
    }
    oldWidth = width;
}

function getProjectId() {
    return $('#project_id').val();
}

function getStudioId() {
    return $('#studio_id').val();
}

//set project id and studio id
function setMissingUrlParameters() {
    console.log("check");
    var project_id = $('#project_id').val();
    var studio_id = $('#studio_id').val();
    if (project_id == null) project_id = '';
    if (studio_id == null) studio_id = '';
    if (
        (project_id != getUrlParameter('project_id'))
        || (studio_id != getUrlParameter('studio_id'))
    ) {
        var project_id = $('#project_id').val();
        var studio_id = $('#studio_id').val();
        var url = window.location.href;
        if (project_id == null) {
            console.log("check called too fast");
            return;
        }
        if (studio_id == null) {
            console.log("check called too fast");
            return;
        }
        url = setUrlParameter(url, 'project_id', project_id);
        url = setUrlParameter(url, 'studio_id', studio_id);
    }
}

function checkSession() {
    var datetime = $('#logout').attr('expires');
    if (datetime == '') return;

    var date1 = parseDateTime(datetime);
    if (date1 == null) return;
    if (date1.getTime() < 0) return;

    var intervalID = setInterval(
        function() {
            var now = new Date().getTime();

            var expiry = Math.floor((date1.getTime() - now) / 1000);
            $('#logout').attr('title', "session expires in " + expiry + " seconds");

            if (expiry < 120) {
                alert("session expires soon!");
            }

            if (expiry < 0) {
                alert("session expired!");
                clearInterval(intervalID);
            }
        }, 5000
    );
}

function checkLabel(element) {
    var value = element.val();
    if (value == '') {
        element.parent().find('div.label').hide();
        element.css("padding-top", "8px");
    } else {
        element.parent().find('div.label').show();
        element.css("padding-top", "0");
    }
}

function initLabels() {
    var selector = 'div.formField input';
    $(selector).each(function() {
        checkLabel($(this));
        $(selector).keyup(function() { checkLabel($(this)); });
    });
};

function copyToClipboard(text) {
    if (text.length == 0) return;
    $('body').append('<textarea style="display:none" id="clipboard">' + text + '</textarea>');
    var copyText = document.getElementById('clipboard');
    copyText.select();
    copyText.setSelectionRange(0, 99999);
    document.execCommand("copy");
}

function setTabs(id, callback) {
    var key = id + ' ul li';
    var i = 0;

    // preselect by URL hash
    var pos = 0;
    $(key).each(function() {
        if (window.location.hash == "#" + $(this).children(":first").attr("href").substr(1))
            pos = i;
        i++
    })

    var i = 0;
    $(key).each(function() {
        var elem = $(this);
        var id = elem.children(":first").attr("href").substr(1);
        if (i == pos) {
            elem.addClass("active");
            $('#' + id).show();
        } else {
            $('#' + id).hide();
            elem.removeClass("active");
        }
        i++;
    });

    $(key).on("click", function() {
        var id2 = $(this).children(":first").attr("href").substr(1);
        $(key).each(function() {
            var elem = $(this);
            var id = elem.children(":first").attr("href").substr(1);
            if (id == id2) {
                $('#' + id).show();
                elem.addClass("active");
            } else {
                $('#' + id).hide();
                elem.removeClass("active");
            }
        });
        if (callback) callback();
        return false;
    });
    $(id + ' ul').addClass("tabContainer");
    $(id).show()
    return false;
}

// Localization

var loc={};
function getLocalization() {
    if (loc == null) {
        loc = new Array();
        loc['back'] = 'zurück';
    }
    return loc;
}

async function loadLocalization(usecases) {
    const usecaseList = ['all', getController(), usecases].filter(Boolean).join(",");
    const url = `localization.cgi?usecase=${encodeURIComponent(usecaseList)}`;
    try {
        Object.assign(loc, await getJson(url));
    } catch (error) {
        console.error("Failed to load localization:", error, url);
    }
}

function getInputWidth(input) {
    const labelText = [...input.parentNode.children]
      .slice(0, [...input.parentNode.children].indexOf(input))
      .reverse()
      .find(e => e.tagName === 'LABEL')?.textContent.trim();
    const text = [input.value, labelText].filter(Boolean).reduce((a, b) => a.length >= b.length ? a : b, "");
    const canvas = getInputWidth.canvas || (getInputWidth.canvas = document.createElement("canvas"));
    const ctx = canvas.getContext("2d");
    const style = window.getComputedStyle(input);
    ctx.font = `${style.fontSize} ${style.fontFamily}`;
    const metrics = ctx.measureText(text+"----");
    return metrics.width +"px";
}

function setInputAutoWidth() {
    document.querySelectorAll("input").forEach(input => {
        if (input.type=="checkbox")return;
        if (input.type=="file")return;
        if (input.type=="submit")return;
        input.style.width = getInputWidth(input);
    });
    document.body.addEventListener("input", function(e) {
        if (e.target.tagName.toLowerCase() === "input") {
            const input = e.target;
            if (input.type=="checkbox")return;
            input.style.width = getInputWidth(input);
        }
    });
}

function getTextareaHeight(textarea) {
    textarea.style.height = "auto";
    return textarea.scrollHeight + 32 + "px";
}

function setTextareaAutoHeight() {
    document.querySelectorAll("textarea").forEach(textarea => {
        textarea.style.height = getTextareaHeight(textarea);
    });
    document.body.addEventListener("input", function(e) {
        if (e.target.tagName.toLowerCase() === "textarea") {
            e.target.style.height = getTextareaHeight(e.target);
        }
    });
}

function fullwidth(el) {
    const style = getComputedStyle(el);
    return el.offsetWidth +
        parseFloat(style.marginLeft) +
        parseFloat(style.marginRight);
}

function fullheight(el) {
    const style = getComputedStyle(el);
    return el.offsetHeight +
        parseFloat(style.marginTop) +
        parseFloat(style.marginBottom);
}

function selectCheckbox(selector) {
    $(selector).each(function() {
        $(this).prop('checked', 'checked');
    })
}

function unselectCheckbox(selector) {
    $(selector).each(function() {
        $(this).removeProp('checked');
    })
}

function isChecked(selector) {
    return $(selector).prop('checked');
}

function getGlobalTitle() {
    return $('#breadcrumb').text() || $('.panel-header').first().text() || $('h2').first().text()
    // breadcrumb is set externally
}

document.addEventListener("DOMContentLoaded",async function() {
    setupMenu();
    checkSession();
    setMissingUrlParameters();

    $(window).resize(function() {
        //if(setupMenuHeight) setupMenuHeight();
        if (setupMenu) setupMenu();
    });

    if (getController() == 'calendar') {
        addBackButton();
        return;
    } else {
        await loadLocalization();
        addBackButton();
    }
    document.title = getGlobalTitle();
    initLabels();
    setInputAutoWidth();
    setTextareaAutoHeight();
    $('.scrollable').focus();

    // rotate on click (for up/down lists)
    $(document).on('click', '.toggle-rotate', function() {
        $(this).toggleClass('rotated');
    });
});

console.log(window.loadLocalization)
