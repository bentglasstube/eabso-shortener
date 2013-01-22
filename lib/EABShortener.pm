package EABShortener;
use Dancer ':syntax';
use Dancer::Plugin::Database;

our $VERSION = '1.1';

use Data::Validate::URI 'is_uri';
use LWP::UserAgent;

my $ua = LWP::UserAgent->new(timeout => 5);
my %ext_map = (
  'image/jpeg' => '.jpg',
  'image/png'  => '.png',
  'image/gif'  => '.gif',
  'text/plain' => '.txt',
  'text/html'  => '.html',
);

sub get_extension {
  my ($type) = @_;

  return $ext_map{$type} if exists $ext_map{$type};
  return '';
}

sub get_title {
  my ($type, $body) = @_;

  if (not defined $type) {
    return 'Unknown link';
  } elsif ($type eq 'text/html') {
    if ($body =~ m|<title>(.*?)</title>|si) {
      return $1;
    } else {
      return 'Untitled link';
    }
  } else {
    return $type;
  }
}

get '/' => sub {
  template 'index';
};

my @chars = split //, 'abcdefghijklmnopqrstuvwxyz0123456789';
post '/' => sub {
  if (is_uri(params->{uri})) {
    my $token = join '', map $chars[int(rand(@chars))], 1 .. 6;

    my $title;
    my $resp = $ua->get(params->{uri});

    if ($resp->is_error) {
      $title = $resp->status_line;
    } else {
      (my $type = $resp->header('Content-Type')) =~ s/;.*$//;
      $title = get_title($type, $resp->content);
      $token .= get_extension($type);
    }

    database->quick_insert(links => {
      token   => $token,
      uri     => params->{uri},
      title   => $title,
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
