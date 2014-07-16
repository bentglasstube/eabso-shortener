function pad(n, digits) {
  n = n + '';
  return n.length >= digits ? n : new Array(digits - n.length + 1).join('0') + n;
}

function formatDate(epoch) {
  var date = new Date(epoch * 1000);

  return [
    pad(date.getFullYear(), 4),
    pad(date.getMonth() + 1, 2),
    pad(date.getDate(), 2)
  ].join('-') + ' ' + [
    pad(date.getHours(), 2),
    pad(date.getMinutes(), 2),
    pad(date.getSeconds(), 2)
  ].join(':');
}

function makeLinkElem(link) {
  var html = '<li style="display: none;">';
  if (link.thumb) html += '<a href="' + link.uri + '"><img class="thumb" src="' + link.thumb + '" alt="thumbnail"></a>';
  html += '<p class="link"><a href="/' + link.token + '">' + link.title + '</a></p>';
  html += '<p class="author">' + link.user + '</p>';
  html += '<p class="date">' + formatDate(link.created) + '</p>';
  html += '</li>';

  return html;
}

function saveSettings() {
  console.log('save settings');

  $.cookie('settings-name', $('#settings-name').val(), { expires: 3650 });

  $('#settings').modal('hide');
}

function hasQueryString() {
  return window.location.href.indexOf('?') != -1;
}

function localizeDates() {
  $('.date-ts').each(function() {
    var elem = $(this);

    elem.text(formatDate(elem.text()));
    elem.removeClass('date-ts');
    elem.addClass('date');
  });
}

$(document).ready(function() {
  $('#settings-name').val($.cookie('settings-name'));

  $('#share').submit(function(e) {
    var body = {
      uri:  $('#url').val(),
      user: $.cookie('settings-name'),
    };

    $.post('/', body, function(data) {
      $('#url').val('');

      var message = $('<div class="alert"></div>');
      if (data.error) {
        message.text(data.error);
        message.addClass('alert-danger');
      } else {
        message.text('Shared as ' + data.result);
        message.addClass('alert-success');
      }

      $('.alert').remove();
      $('#links').before(message);
    });

    e.preventDefault();
  });

  if (!hasQueryString()) {
    $(window).scroll(function() {
      if ($(window).scrollTop() == $(document).height() - $(window).height()) {
        $.get('/json?b=' + oldest, function(data) {
          if (data.length > 0) {
            for (i in data) {
              $('#links').append(makeLinkElem(data[i]));
              oldest = data[i].created;
            }
            $('li').fadeIn();
          }
        });
      }
    });

    (function refresh() {
      $.ajax({
        url: '/json?a=' + newest,
        success: function(data) {
          if (data.length > 0) {
            for (i in data) {
              $('#links').prepend(makeLinkElem(data[i]));
            }
            newest = data[0].created;
            $('li').fadeIn();
          }
        },
        complete: function() {
          setTimeout(refresh, 1000);
        },
      });
    })();
  }

  $('#settings form').submit(function(e) {
    saveSettings();
    e.preventDefault();
  });

  $('#save').click(function(e) {
    saveSettings();
    e.preventDefault();
  });
});
