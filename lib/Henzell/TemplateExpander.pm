package Henzell::TemplateExpander;

use strict;
use warnings;

use IPC::Open2;
use JSON;

sub new {
  my ($cls, %opt) = @_;
  bless \%opt, $cls
}

sub _root {
  $ENV{HENZELL_ROOT} or die "HENZELL_ROOT is not set\n"
}

sub _echo_service {
  my $self = shift;
  if (!$self->{_iecho}) {
    open2(my $in, my $out, $self->_root() . '/commands/echo-pipe.rb')
      or die "Couldn't spawn echo service\n";
    $self->{_iecho} = $in;
    $self->{_oecho} = $out;
  }
  ($self->{_iecho}, $self->{_oecho})
}

sub expand {
  my ($self, $template, $argline, %opt) = @_;
  my ($in, $out) = $self->_echo_service();
  my $broken_pipe;
  local $SIG{PIPE} = sub { $broken_pipe = 1; };
  print $out encode_json({ msg => $template,
                           args => $argline,
                           command_env => {
                             PRIVMSG => $opt{irc_msg}{private}
                           },
                           env => $opt{env} }), "\n";
  my $res = <$in>;
  if ($broken_pipe || !defined($res)) {
    if ($self->{retried}) {
      delete $self->{retried};
      return "Could not expand $template: subprocess error\n";
    }

    $self->{retried} = 1;
    close $in;
    close $out;
    delete $self->{_iecho};
    delete $self->{_oecho};
    return $self->expand($template, $argline, %opt);
  }

  delete $self->{retried};
  my $json = decode_json($res);
  return "Could not parse response: $res\n" unless $json;
  return $json->{err} if $json && $json->{err};
  $json && $json->{res}
}

1
