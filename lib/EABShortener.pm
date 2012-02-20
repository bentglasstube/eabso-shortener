package EABShortener;
use Dancer ':syntax';
use Dancer::Plugin::Database;

our $VERSION = '0.1';

use URI::Title 'title';
use Data::Validate::URI 'is_uri';

get '/' => sub {
  template 'index';
};

my @chars = split //, 'abcdefghijklmnopqrstuvwxyz0123456789';
post '/' => sub {
  if (is_uri(params->{uri})) {
    my $token = join '', map $chars[int(rand(@chars))], 1 .. 6;

    database->quick_insert(links => {
      token   => $token,
      uri     => params->{uri},
      title   => title(params->{uri}) || 'Unknown link',
      user    => params->{user} || 'Some asshole',
      created => time,
    });

    content_type 'application/json';
    return to_json { result => "http://eab.so/$token" };
  } else {
    content_type 'application/json';
    return to_json { error => 'invalid uri' };
  }
};

get '/rss' => sub {
  content_type 'text/xml';

  my @links = database->quick_select(links => {}, { 
    order_by => { desc => 'created' }, 
    limit => 25,
  });
  template 'rss', { links => \@links };
};

get '/crx' => sub {
  redirect 'https://chrome.google.com/webstore/detail/cdjnlghjdbiambiakngkffonbaeoikcn';
};

any '/new.pl' => sub {
  content_type 'application/json';
  return to_json { error => 'update extension' };
};

get '/:token' => sub {
  my $link = database->quick_select(links => { token => params->{token} });

  if ($link) {
    redirect $link->{uri};
  } else {
    status 'not_found';
    template '404';
  }
};

true;
