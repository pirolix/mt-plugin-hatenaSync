package MT::Plugin::OMV::hatenaSync;

use strict;
use MT::Entry;
use XML::Atom::Entry;
use XML::Atom::Client;

use vars qw( $MYNAME $VERSION );
$MYNAME = 'hatenaSync';
$VERSION = '0.02';

use base qw( MT::Plugin );
my $plugin = __PACKAGE__->new({
    name => $MYNAME,
    id => lc $MYNAME,
    key => lc $MYNAME,
    version => $VERSION,
    author_name => 'Open MagicVox.net',
    author_link => 'http://www.magicvox.net/',
    doc_link => 'http://www.magicvox.net/archive/2009/02111447/',
    description => <<PERLHEREDOC,
<__trans phrase="Synchronize the posted entry with Hatena diary">
PERLHEREDOC
#    l10n_class => $MYNAME. '::L10N',
    blog_config_template => 'config.tmpl',
    settings => new MT::PluginSettings([
        [ 'htn_username', { Default => undef, scope => 'blog' } ],
        [ 'htn_password', { Default => undef, scope => 'blog' } ],
    ]),
});
MT->add_plugin ($plugin);

sub instance { $plugin; }



MT->add_callback ('BuildFile', 5, $plugin, \&_entry_post_save);
sub _entry_post_save {
    my ($eh, %opt) = @_;

    my $ctx = $opt{Context};
    my $entry = $ctx->stash ('entry')
        or return 1;

    my $blog_id = $entry->blog_id;
    my $scope = "blog:$blog_id";
    my $htn_username = &instance->get_config_value ('htn_username', $scope);
    my $htn_password = &instance->get_config_value ('htn_password', $scope);
    defined $htn_username and defined $htn_password
        or return;# no settings

    my $pdata = load_plugindata (key_name ($entry->id)) || {};
    if (!$pdata->{EditURI} && $entry->status == MT::Entry::RELEASE()) {
        my $atom_client = XML::Atom::Client->new;
        $atom_client->username ($htn_username);
        $atom_client->password ($htn_password);

        my $atom_entry = XML::Atom::Entry->new;
        $atom_entry->title ($entry->title);
        $atom_entry->content (
                sprintf "[%s:title=%s]\n\n%s",
                $entry->permalink, $entry->title, $entry->text);

        my $PostURI = "http://d.hatena.ne.jp/$htn_username/atom/blog";
        $pdata->{EditURI} = $atom_client->createEntry ($PostURI, $atom_entry)
            or return $atom_client->errstr;
        save_plugindata (key_name ($entry->id), $pdata);
    }
}



########################################################################
sub key_name { 'entry_id:'. $_[0]; }

use MT::PluginData;

sub save_plugindata {
    my ($key, $data_ref) = @_;
    my $pd = MT::PluginData->load({ plugin => &instance->id, key=> $key });
    if (!$pd) {
        $pd = MT::PluginData->new;
        $pd->plugin( &instance->id );
        $pd->key( $key );
    }
    $pd->data( $data_ref );
    $pd->save;
}

sub load_plugindata {
    my ($key) = @_;
    my $pd = MT::PluginData->load({ plugin => &instance->id, key=> $key })
        or return undef;
    $pd->data;
}

1;
__END__
