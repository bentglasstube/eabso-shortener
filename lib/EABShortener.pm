package EABShortener;
use Dancer ':syntax';

our $VERSION = '0.1';

use URI::Title 'title';
use Data::Validate::URI 'is_uri';

my @links = ();
my %links = ();

get '/' => sub {
  template 'index';
};

my @chars = split //, 'abcdefghijklmnopqrstuvwxyz0123456789';
post '/' => sub {
  if (is_uri(params->{uri})) {
    my $token = join '', map $chars[int(rand(@chars))], 1 .. 6;
    my $link = {
      token => $token,
      uri   => params->{uri},
      title => title(params->{uri}) || 'Unknown link',
      user  => params->{user} || 'Some asshole',
    };

    unshift @links, $link;
    $links{$token} = params->{uri};

    if (@links > config->{max_links}) {
      my $old = pop @links;
      delete $links{$old->{token}};
    }

    content_type 'application/json';
    return to_json { result => "http://eab.so/$token" };
  } else {
    content_type 'application/json';
    return to_json { error => 'invalid uri' };
  }
};

get '/rss' => sub {
  content_type 'text/xml';
  template 'rss', { links => [@links[0 .. 9]] };
};

get '/crx' => sub {
  redirect 'https://chrome.google.com/webstore/detail/cdjnlghjdbiambiakngkffonbaeoikcn';
};

get '/:token' => sub {
  if (exists $links{params->{token}}) {
    redirect $links{params->{token}};
  } else {
    status 'not_found';
    return '';
  }
};

true;
