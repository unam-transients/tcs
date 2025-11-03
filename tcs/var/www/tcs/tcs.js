////////////////////////////////////////////////////////////////////////

// This file is part of the UNAM telescope control system.

////////////////////////////////////////////////////////////////////////

// Copyright © 2010, 2011, 2012, 2013, 2014, 2017, 2018, 2019 Alan M. Watson <alan@astro.unam.mx>
//
// Permission to use, copy, modify, and distribute this software for any
// purpose with or without fee is hereby granted, provided that the
// above copyright notice and this permission notice appear in all
// copies.
//
// THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL
// WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE
// AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL
// DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR
// PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
// TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
// PERFORMANCE OF THIS SOFTWARE.

////////////////////////////////////////////////////////////////////////

function newcomponent(subset, title)
{
  $("title").text(projectname + " " + interfacetype + ": " + title);
  $("h1").text(projectname + " " + interfacetype + ": " + title);
  $("div#status").html("");
  $("div#log").html("");
  refreshstatus(subset);
  refreshlog(subset);
}

function milliseconds() {
  var d = new Date();
  return d.valueOf();
}

var refreshstatussubset = false;
var refreshstatusinterval = 1000;

function refreshstatus(subset)
{
  var onceonly = !!refreshstatussubset;
  refreshstatussubset = subset;
  refreshstatushelper(subset, onceonly);
}

function refreshstatushelper(subset, onceonly) 
{
  var start = milliseconds();
  var data = {};
  data.start = start;
  $.ajax({
    type: "get",
    url: "status/" + subset + ".html",
    data: data,
    dataType: "html",
    success: function (data, status, request) {
      if (subset == refreshstatussubset) {
        $("div#status").html(data);
      }
    },
    complete: function (request, status) {
      if (!onceonly) {
        var end = milliseconds();
        var interval = Math.max (0, refreshstatusinterval - (end - start));
        setTimeout("refreshstatushelper(\"" + refreshstatussubset + "\", false)", interval);
      }
    }
  });
}

var refreshlogsubset = false;
var refreshloginterval = 1000;

function refreshlog(subset)
{
  var onceonly = !!refreshlogsubset;
  refreshlogsubset = subset;
  refreshloghelper(subset, onceonly);
}

function refreshloghelper(subset, onceonly) {
  var start = milliseconds();
  var data = {};
  data.start = start;
  $.ajax({
    type: "get",
    url: "log/" + subset + ".html",
    data: data,
    dataType: "html",
    success: function (data, status, request) {
      if (subset == refreshlogsubset) {
        $("div#log").html(data);
      }
    },
    complete: function (request, status) {
      if (!onceonly) {
        var end = milliseconds();
        var interval = Math.max (0, refreshloginterval - (end - start));
        setTimeout("refreshloghelper(\"" + refreshlogsubset + "\", false)", interval);
      }
    }
  });
}

var refreshalertsinterval = 1000;

function refreshalerts()
{
  refreshalertshelper(true);
}

function refreshalertshelper(onceonly) {
  var start = milliseconds();
  var data = {};
  data.start = start;
  $.ajax({
    type: "get",
    url: "status/alerts.html",
    data: data,
    dataType: "html",
    success: function (data, status, request) {
      $("div#alerts").html(data);
    },
    complete: function (request, status) {
      if (!onceonly) {
        var end = milliseconds();
        var interval = Math.max (0, refreshalertsinterval - (end - start));
        setTimeout("refreshalertshelper(\"" + refreshalertssubset + "\", false)", interval);
      }
    }
  });
}

var refreshimagehandler;
var refreshimageinterval = 1000;

function refreshimage(imagemap)
{
  refreshimagehandler = function () {
    var start = milliseconds();
    $.each(imagemap, function (id, src) {
      if ($("img#" + id).prop("complete")) {
        var srcisquery = src.indexOf("?") != -1;
        $("img#" + id).prop("src", src + (srcisquery ? "&" : "?") + start);
      }
    });
    var end = milliseconds();
    var wait = Math.max(0, refreshimageinterval - (end - start));
    setTimeout("refreshimagehandler()", wait);
  };
  refreshimagehandler();
}

confirmrequest = false;

function submitrequest(request) {
  if (!confirmrequest || confirm("Do you want to submit this request?\n\n" + request + "\n")) {
    $.ajax({
      type: "get",
      url: "request.cgi",
      data: {
        request: request
      },
      dataType: "text",
      success: function (data, status, request) {
        if (data != "ok\r\n") {
          alert(data);
        }
      },
      error: function (data, status, error) {
        alert("server error: " + status + " (" + error + ").");
      }
    });
  }
  return false;
}

$(function () {
  $("form#system-notifyemergency").submit(function () {
    return submitrequest("notifyemergency");
  });
  $("form#system-restart").submit(function () {
    return submitrequest("restart");
  });
  $("form#system-rebootcomputers").submit(function () {
    return submitrequest("rebootcomputers");
  });
  $("form#system-rebootinstrument").submit(function () {
    return submitrequest("rebootinstrument");
  });
  $("form#system-rebootplatform").submit(function () {
    return submitrequest("rebootplatform");
  });
  $("form#system-rebootmount").submit(function () {
    return submitrequest("rebootmount");
  });
  $("form#system-clearblocks").submit(function () {
    return submitrequest("clearblocks");
  });
  $("form#system-loadblocks").submit(function () {
    return submitrequest("loadblocks");
  });
  $("form#emergencystop").submit(function () {
    return submitrequest("emergencystop");
  });
  $("form#emergencyclose").submit(function () {
    return submitrequest("supervisor emergencyclose");
  });
  $("form#executor-initialize").submit(function () {
    return submitrequest("executor initialize");
  });
  $("form#executor-recover").submit(function () {
    return submitrequest("executor recover");
  });
  $("form#executor-reset").submit(function () {
    return submitrequest("executor reset");
  });
  $("form#lights-switchon").submit(function () {
    return submitrequest("lights switchon");
  });
  $("form#lights-switchoff").submit(function () {
    return submitrequest("lights switchoff");
  });
  $("form#louvers-open").submit(function () {
    return submitrequest("louvers open");
  });
  $("form#louvers-close").submit(function () {
    return submitrequest("louvers close");
  });
  $("form#louvers-cool").submit(function () {
    return submitrequest("louvers cool");
  });
  $("form#supervisor-enable").submit(function () {
    return submitrequest("supervisor enable");
  });
  $("form#supervisor-disable").submit(function () {
    return submitrequest("supervisor disable");
  });
  $("form#supervisor-open").submit(function () {
    return submitrequest("supervisor open");
  });
  $("form#supervisor-close").submit(function () {
    return submitrequest("supervisor close");
  });
  $("form#supervisor-abandonnight").submit(function () {
    return submitrequest("supervisor abandonnight");
  });
  $("form#supervisor-emergencyclose").submit(function () {
    return submitrequest("supervisor emergencyclose");
  });
  $("form#selector-enable").submit(function () {
    return submitrequest("selector enable");
  });
  $("form#selector-disable").submit(function () {
    return submitrequest("selector disable");
  });
  $("form#selector-refocus").submit(function () {
    return submitrequest("selector refocus");
  });
  $("form#selector-reselect").submit(function () {
    return submitrequest("selector reselect");
  });
  $("form#telescope-stop").submit(function () {
    return submitrequest("telescope stop");
  });
  $("form#telescope-initialize").submit(function () {
    return submitrequest("telescope initialize");
  });
  $("form#telescope-reset").submit(function () {
    return submitrequest("telescope reset");
  });
  $("form#telescope-open").submit(function () {
    return submitrequest("telescope open");
  });
  $("form#telescope-close").submit(function () {
    return submitrequest("telescope close");
  });
  $("form#telescope-move").submit(function () {
    return submitrequest("telescope move " + $("input#move-args").val());
  });
  $("form#telescope-movetoidle").submit(function () {
    return submitrequest("telescope movetoidle");
  });
  $("form#telescope-track").submit(function () {
    return submitrequest("telescope track " + $("input#track-args").val());
  });
  $("form#telescope-trackcatalogobject").submit(function () {
    return submitrequest("telescope trackcatalogobject " + $("input#trackcatalogobject-args").val());
  });
  $("form#telescope-tracktopocentric").submit(function () {
    return submitrequest("telescope tracktopocentric " + $("input#tracktopocentric-args").val());
  });
  $("form#telescope-offset").submit(function () {
    return submitrequest("telescope offset " + $("input#offset-args").val());
  });
  $("form#telescope-setpointingaperture").submit(function () {
    return submitrequest("telescope setpointingaperture " + $("input#setpointingaperture-args").val());
  });
  $("form#telescope-movesecondary").submit(function () {
    return submitrequest("telescope movesecondary " + $("input#movesecondary-args").val());
  });
  $("form#telescope-other").submit(function () {
    return submitrequest("telescope " + $("input#other-request").val());
  });
});
