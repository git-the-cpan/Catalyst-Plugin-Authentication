#!/usr/bin/perl

package Catalyst::Plugin::Authentication;

use base qw/Class::Accessor::Fast Class::Data::Inheritable/;

BEGIN {
    __PACKAGE__->mk_accessors(qw/_user/);
    __PACKAGE__->mk_classdata($_) for qw/_auth_stores _auth_store_names/;
}

use strict;
use warnings;

use Tie::RefHash;
use Class::Inspector;

# this optimization breaks under Template::Toolkit
# use user_exists instead
#BEGIN {
#	require constant;
#	constant->import(have_want => eval { require Want });
#}

our $VERSION = "0.04";

sub set_authenticated {
    my ( $c, $user ) = @_;

    $c->user($user);
    $c->request->{user} = $user;    # compatibility kludge

    if (    $c->isa("Catalyst::Plugin::Session")
        and $c->config->{authentication}{use_session}
        and $user->supports("session") )
    {
        $c->save_user_in_session($user);
    }

    $c->NEXT::set_authenticated($user);
}

sub user {
    my $c = shift;

    if (@_) {
        return $c->_user(@_);
    }

    my $user = $c->_user;

    if ( $user and !Scalar::Util::blessed($user) ) {
#		return 1 if have_want() && Want::want("BOOL");
        return $c->auth_restore_user($user);
    }

    return $user;
}

sub user_exists {
	my $c = shift;
	return defined($c->_user);
}

sub save_user_in_session {
    my ( $c, $user ) = @_;

    my $store = $user->store || ref $user;
    $c->session->{__user_store} = $c->get_auth_store_name($store) || $store;
    $c->session->{__user} = $user->for_session;
}

sub logout {
    my $c = shift;

    $c->user(undef);

    if (    $c->isa("Catalyst::Plugin::Session")
        and $c->config->{authentication}{use_session} )
    {
        delete @{ $c->session }{qw/__user __user_store/};
    }
    
    $c->NEXT::logout(@_);
}

sub get_user {
    my ( $c, $uid ) = @_;

    if ( my $store = $c->default_auth_store ) {
        return $store->get_user($uid);
    }
    else {
        Catalyst::Exception->throw(
                "The user id $uid was passed to an authentication "
              . "plugin, but no default store was specified" );
    }
}

sub prepare {
    my $c = shift->NEXT::prepare(@_);

    if ( $c->isa("Catalyst::Plugin::Session")
        and !$c->user )
    {
        if ( $c->sessionid and my $frozen_user = $c->session->{__user} ) {
            $c->_user($frozen_user);
        }
    }

    return $c;
}

sub auth_restore_user {
    my ( $c, $frozen_user, $store_name ) = @_;

    return
      unless $c->isa("Catalyst::Plugin::Session")
      and $c->config->{authentication}{use_session}
      and $c->sessionid;

    $store_name  ||= $c->session->{__user_store};
    $frozen_user ||= $c->session->{__user};

    my $store = $c->get_auth_store($store_name);
    $c->_user( my $user = $store->from_session( $c, $frozen_user ) );

    return $user;

}

sub setup {
    my $c = shift;

    my $cfg = $c->config->{authentication} || {};

    %$cfg = (
        use_session => 1,
        %$cfg,
    );

    $c->register_auth_stores(
        default => $cfg->{store},
        %{ $cfg->{stores} || {} },
    );

    $c->NEXT::setup(@_);
}

sub get_auth_store {
    my ( $self, $name ) = @_;
    $self->auth_stores->{$name} || ( Class::Inspector->loaded($name) && $name );
}

sub get_auth_store_name {
    my ( $self, $store ) = @_;
    $self->auth_store_names->{$store};
}

sub register_auth_stores {
    my ( $self, %new ) = @_;

    foreach my $name ( keys %new ) {
        my $store = $new{$name} or next;
        $self->auth_stores->{$name}       = $store;
        $self->auth_store_names->{$store} = $name;
    }
}

sub auth_stores {
    my $self = shift;
    $self->_auth_stores(@_) || $self->_auth_stores( {} );
}

sub auth_store_names {
    my $self = shift;

    $self->_auth_store_names || do {
        tie my %hash, 'Tie::RefHash';
        $self->_auth_store_names( \%hash );
      }
}

sub default_auth_store {
    my $self = shift;

    if ( my $new = shift ) {
        $self->register_auth_stores( default => $new );
    }

    $self->get_auth_store("default");
}

__PACKAGE__;

__END__

=pod

=head1 NAME

Catalyst::Plugin::Authentication - Infrastructure plugin for the Catalyst
authentication framework.

=head1 SYNOPSIS

    use Catalyst qw/
        Authentication
        Authentication::Store::Foo
        Authentication::Credential::Password
    /;

    # later on ...
    # ->login is provided by the Credential::Password module
    $c->login('myusername', 'mypassword');
    my $age = $c->user->age;
    $c->logout;

=head1 DESCRIPTION

The authentication plugin provides generic user support. It is the basis 
for both authentication (checking the user is who they claim to be), and 
authorization (allowing the user to do what the system authorises them to do).

Using authentication is split into two parts. A Store is used to actually 
store the user information, and can store any amount of data related to 
the user. Multiple stores can be accessed from within one application. 
Credentials are used to verify users, using the store, given data from 
the frontend.

To implement authentication in a catalyst application you need to add this 
module, plus at least one store and one credential module.

Authentication data can also be stored in a session, if the application 
is using the L<Catalyst::Plugin::Session> module.

=head1 METHODS

=over 4 

=item user

Returns the currently logged in user or undef if there is none.

=item user_exists

Whether or not a user is logged in right now.

The reason this method exists is that C<< $c->user >> may needlessly load the
user from the auth store.

If you're just going to say

	if ( $c->user_user ) {
		# foo
	} else {
		$c->forward("login");
	}

it should be more efficient than C<< $c->user >> when a user is marked in the session
but C<< $c->user >> hasn't been called yet.

=item logout

Delete the currently logged in user from C<user> and the session.

=item get_user $uid

Fetch a particular users details, defined by the given ID, via the default store.

=back

=head1 CONFIGURATION

=over 4

=item use_session

Whether or not to store the user's logged in state in the session, if the
application is also using the L<Catalyst::Plugin::Session> plugin. This 
value is set to true per default.

=item store

If multiple stores are being used, set the module you want as default here.

=item stores

If multiple stores are being used, you need to provide a name for each store
here, as a hash, the keys are the names you wish to use, and the values are
the the names of the plugins.

 # example
 __PACKAGE__->config( authentication => {
                        store => 'Catalyst::Plugin::Authentication::Store::HtPasswd',
                        stores => { 
                           'dbic' => 'Catalyst::Plugin::Authentication::Store::DBIC'
                                  }
                                         });

=back

=head1 METHODS FOR STORE MANAGEMENT

=over 4

=item default_auth_store

Return the store whose name is 'default'.

This is set to C<< $c->config->{authentication}{store} >> if that value exists,
or by using a Store plugin:

	use Catalyst qw/Authentication Authentication::Store::Minimal/;

Sets the default store to
L<Catalyst::Plugin::Authentication::Store::Minimal::Backend>.


=item get_auth_store $name

Return the store whose name is $name.

=item get_auth_store_name $store

Return the name of the store $store.

=item auth_stores

A hash keyed by name, with the stores registered in the app.

=item auth_store_names

A ref-hash keyed by store, which contains the names of the stores.

=item register_auth_stores %stores_by_name

Register stores into the application.

=back

=head1 INTERNAL METHODS

=over 4

=item set_authenticated $user

Marks a user as authenticated. Should be called from a
C<Catalyst::Plugin::Authentication::Credential> plugin after successful
authentication.

This involves setting C<user> and the internal data in C<session> if
L<Catalyst::Plugin::Session> is loaded.

=item auth_restore_user $user

Used to restore a user from the session, by C<user> only when it's actually
needed.

=item save_user_in_session $user

Used to save the user in a session.

=item prepare

Revives a user from the session object if there is one.

=item setup

Sets the default configuration parameters.

=item 

=back

=head1 SEE ALSO

L<Catalyst::Plugin::Authentication::Credential::Password>,
L<Catalyst::Plugin::Authentication::Store::Minimal>,
L<Catalyst::Plugin::Authorization::ACL>,
L<Catalyst::Plugin::Authorization::Roles>.

=head1 DON'T SEE ALSO

This module along with it's sub plugins deprecate a great number of other
modules. These include Catalyst::Plugin::Authentication::Simple,
Catalyst::Plugin::Authentication::CDBI.

At the time of writing these plugins have not yet been replaced or updated, but
should be eventually: Catalyst::Plugin::Authentication::OpenID,
Catalyst::Plugin::Authentication::LDAP,
Catalyst::Plugin::Authentication::CDBI::Basic,
Catalyst::Plugin::Authentication::Basic::Remote

=head1 AUTHORS

Yuval Kogman, C<nothingmuch@woobling.org>

Jess Robinson

David Kamholz

=head1 COPYRIGHT & LICENSE

        Copyright (c) 2005 the aforementioned authors. All rights
        reserved. This program is free software; you can redistribute
        it and/or modify it under the same terms as Perl itself.

=cut
