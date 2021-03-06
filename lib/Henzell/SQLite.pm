package Henzell::SQLite;

use strict;
use warnings;

use DBI;

sub new {
  my ($cls, $dbfile) = @_;
  bless { file => $dbfile }, $cls
}

sub mtime {
  my $self = shift;
  (stat($self->file()))[9]
}

sub begin_work {
  shift()->db()->begin_work()
}

sub commit {
  shift()->db()->commit()
}

sub rollback {
  shift()->db()->rollback()
}

sub db {
  my $self = shift;
  $self->{db} ||= $self->_open() or die "Can't open $self->file(): $!\n"
}

sub do {
  my $self = shift;
  $self->db()->do(@_)
}

sub _open {
  my $self = shift;
  my $db = DBI->connect("dbi:SQLite:dbname=" . $self->file(), "", "");
  $db->{AutoCommit} = 1;
  $db->do('PRAGMA foreign_keys = ON') or
    die "Could not enable foreign keys: $db->errstr\n";
  $db
}

sub disable_fsync {
  my $self = shift;
  my $db = $self->db();
  $db->do('PRAGMA synchronous = off') or
    die "Could not disable fsync: $db->errstr\n";
}

sub load_sql_file {
  my ($self, $file) = @_;
  return unless -f $file;
  my $text = do { local (@ARGV, $/) = $file; <> };
  my $db = $self->db();
  for my $fragment (split /;/, $text) {
    s/^\s+//, s/\s+$// for $fragment;
    next unless $fragment =~ /\S/;
    $db->do($fragment) or die "Failed to execute $fragment: $db->errstr\n";
  }
}

sub has_table {
  my ($self, $table) = @_;
  $self->db()->table_info(undef, undef, $table)->fetchrow_arrayref()
}

sub prepare {
  my ($self, $query) = @_;
  my $db = $self->db();
  $db->prepare($query) or die "Couldn't prepare $query: $db->errstr\n"
}

sub exec {
  my ($self, $query, @binds) = @_;
  my $st = $self->prepare($query);
  $self->execute_st($st, @binds)
    or die "Couldn't execute $query: " . $self->errstr() . "\n";
  $st
}

sub execute_st {
  my ($self, $st, @binds) = @_;
  my $tries = 50;
  while ($tries-- > 0) {
    my $res = $st->execute(@binds);
    return $res if $res;
    unless ($self->errstr() =~ /\blocked\b/) {
      die $self->errstr();
    }
    sleep 1;
  }
  undef
}

sub query_val {
  my ($self, $query, @binds) = @_;
  my $st = $self->exec($query, @binds);
  my $row = $st->fetchrow_arrayref;
  $row && $row->[0]
}

sub errstr {
  shift()->db()->errstr
}

sub file {
  shift()->{file}
}

sub exist {
  my $self = shift;
  -f($self->file())
}

1
