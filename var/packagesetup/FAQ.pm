# --
# FAQ.pm - code to excecute during package installation
# Copyright (C) 2001-2010 OTRS AG, http://otrs.org/
# --
# $Id: FAQ.pm,v 1.11 2010-11-22 14:35:36 ub Exp $
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see L<http://www.gnu.org/licenses/agpl.txt>.
# --

package var::packagesetup::FAQ;

use strict;
use warnings;

use Kernel::Config;
use Kernel::System::SysConfig;
use Kernel::System::CSV;
use Kernel::System::Group;
use Kernel::System::Stats;
use Kernel::System::User;
use Kernel::System::Valid;
use Kernel::System::LinkObject;
use Kernel::System::FAQ;

use vars qw(@ISA $VERSION);
$VERSION = qw($Revision: 1.11 $) [1];

=head1 NAME

FAQ.pm - code to excecute during package installation

=head1 SYNOPSIS

All functions

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object

    use Kernel::Config;
    use Kernel::System::Log;
    use Kernel::System::Main;
    use Kernel::System::Time;
    use Kernel::System::DB;
    use Kernel::System::XML;
    use var::packagesetup::FAQ;

    my $ConfigObject = Kernel::Config->new();
    my $LogObject    = Kernel::System::Log->new(
        ConfigObject => $ConfigObject,
    );
    my $MainObject = Kernel::System::Main->new(
        ConfigObject => $ConfigObject,
        LogObject    => $LogObject,
    );
    my $TimeObject = Kernel::System::Time->new(
        ConfigObject => $ConfigObject,
        LogObject    => $LogObject,
    );
    my $DBObject = Kernel::System::DB->new(
        ConfigObject => $ConfigObject,
        LogObject    => $LogObject,
        MainObject   => $MainObject,
    );
    my $XMLObject = Kernel::System::XML->new(
        ConfigObject => $ConfigObject,
        LogObject    => $LogObject,
        DBObject     => $DBObject,
        MainObject   => $MainObject,
    );
    my $CodeObject = var::packagesetup::FAQ->new(
        ConfigObject => $ConfigObject,
        LogObject    => $LogObject,
        MainObject   => $MainObject,
        TimeObject   => $TimeObject,
        DBObject     => $DBObject,
        XMLObject    => $XMLObject,
    );

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for my $Object (
        qw(ConfigObject LogObject MainObject TimeObject DBObject XMLObject EncodeObject)
        )
    {
        $Self->{$Object} = $Param{$Object} || die "Got no $Object!";
    }

    # create needed sysconfig object
    $Self->{SysConfigObject} = Kernel::System::SysConfig->new( %{$Self} );

    # rebuild ZZZ* files
    $Self->{SysConfigObject}->WriteDefault();

    # define the ZZZ files
    my @ZZZFiles = (
        'ZZZAAuto.pm',
        'ZZZAuto.pm',
    );

    # reload the ZZZ files (mod_perl workaround)
    for my $ZZZFile (@ZZZFiles) {

        PREFIX:
        for my $Prefix (@INC) {
            my $File = $Prefix . '/Kernel/Config/Files/' . $ZZZFile;
            next PREFIX if !-f $File;
            do $File;
            last PREFIX;
        }
    }

    # create needed objects
    $Self->{ConfigObject} = Kernel::Config->new();
    $Self->{CSVObject}    = Kernel::System::CSV->new( %{$Self} );
    $Self->{GroupObject}  = Kernel::System::Group->new( %{$Self} );
    $Self->{UserObject}   = Kernel::System::User->new( %{$Self} );
    $Self->{ValidObject}  = Kernel::System::Valid->new( %{$Self} );
    $Self->{LinkObject}   = Kernel::System::LinkObject->new( %{$Self} );
    $Self->{FAQObject}    = Kernel::System::FAQ->new( %{$Self} );
    $Self->{StatsObject}  = Kernel::System::Stats->new(
        %{$Self},
        UserID => 1,
    );

    # define file prefix
    $Self->{FilePrefix} = 'FAQ';

    return $Self;
}

=item CodeInstall()

run the code install part

    my $Result = $CodeObject->CodeInstall();

=cut

sub CodeInstall {
    my ( $Self, %Param ) = @_;

    # insert the faq states
    $Self->_InsertFAQStates();

    # add the group faq
    $Self->_GroupAdd(
        Name        => 'faq',
        Description => 'faq database users',
    );

    # add the group faq_admin
    $Self->_GroupAdd(
        Name        => 'faq_admin',
        Description => 'faq admin users',
    );

    # add the group faq_approval
    $Self->_GroupAdd(
        Name        => 'faq_approval',
        Description => 'faq approval users',
    );

    # install stats
    $Self->{StatsObject}->StatsInstall(
        FilePrefix => $Self->{FilePrefix},
    );

    return 1;
}

=item CodeReinstall()

run the code reinstall part

    my $Result = $CodeObject->CodeReinstall();

=cut

sub CodeReinstall {
    my ( $Self, %Param ) = @_;

    # insert the faq states
    $Self->_InsertFAQStates();

    # add the group faq
    $Self->_GroupAdd(
        Name        => 'faq',
        Description => 'faq database users',
    );

    # add the group faq_admin
    $Self->_GroupAdd(
        Name        => 'faq_admin',
        Description => 'faq admin users',
    );

    # add the group faq_approval
    $Self->_GroupAdd(
        Name        => 'faq_approval',
        Description => 'faq approval users',
    );

    # install stats
    $Self->{StatsObject}->StatsInstall(
        FilePrefix => $Self->{FilePrefix},
    );

    return 1;
}

=item CodeUpgrade()

run the code upgrade part

    my $Result = $CodeObject->CodeUpgrade();

=cut

sub CodeUpgrade {
    my ( $Self, %Param ) = @_;

    # install stats
    $Self->{StatsObject}->StatsInstall(
        FilePrefix => $Self->{FilePrefix},
    );

    return 1;
}

=item CodeUpgradeSpecial()

run special code upgrade part

    my $Result = $CodeObject->CodeUpgradeSpecial();

=cut

sub CodeUpgradeSpecial {
    my ( $Self, %Param ) = @_;

    # convert \n to <br> for existing articles
    $Self->_ConvertNewlines();

    # start normal code upgrade
    $Self->CodeUpgrade();

    return 1;
}

=item CodeUninstall()

run the code uninstall part

    my $Result = $CodeObject->CodeUninstall();

=cut

sub CodeUninstall {
    my ( $Self, %Param ) = @_;

    # deactivate the group faq
    $Self->_GroupDeactivate(
        Name => 'faq',
    );

    # deactivate the group faq_admin
    $Self->_GroupDeactivate(
        Name => 'faq_admin',
    );

    # deactivate the group faq_approval
    $Self->_GroupDeactivate(
        Name => 'faq_approval',
    );

    # uninstall stats
    $Self->{StatsObject}->StatsUninstall(
        FilePrefix => $Self->{FilePrefix},
    );

    # delete all links with FAQ articles
    $Self->_LinkDelete();

    return 1;
}

=item _InsertFAQStates()

inserts needed FAQ states into table

    my $Result = $CodeObject->_InsertFAQStates();

=cut

sub _InsertFAQStates {
    my ( $Self, %Param ) = @_;

    # define faq_state_types => faq_states
    my %State = (
        'internal' => 'internal (agent)',
        'external' => 'external (customer)',
        'public'   => 'public (all)',
    );

    for my $Type (qw( internal external public )) {

        # get the state type
        my $StateTypeRef = $Self->{FAQObject}->StateTypeGet(
            Name   => $Type,
            UserID => 1,
        );

        # add the state
        $Self->{FAQObject}->StateAdd(
            Name   => $State{$Type},
            TypeID => $StateTypeRef->{ID},
            UserID => 1,
        );
    }

    return 1;
}

=item _ConvertNewlines()

coverts all \n into <br> for Fields 1-6 in all existing FAQ articles

    my $Result = $CodeObject->_ConvertNewlines();

=cut

sub _ConvertNewlines {
    my ( $Self, %Param ) = @_;

    # only convert \n to <br> if HTML view is enabled
    return if !$Self->{ConfigObject}->Get('FAQ::Item::HTML');

    # get all FAQ IDs
    my @FAQIDs;
    $Self->{DBObject}->Prepare(
        SQL => "SELECT id FROM faq_item",
    );
    while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
        push( @FAQIDs, $Row[0] );
    }

    ID:
    for my $ItemID (@FAQIDs) {

        # get FAQ data
        my %FAQ = $Self->{FAQObject}->FAQGet(
            ItemID => $ItemID,
            UserID => 1,
        );

        # get FAQ article fields 1-6
        my $FoundNewline;
        KEY:
        for my $Key (qw (Field1 Field2 Field3 Field4 Field5 Field6)) {
            next KEY if !$FAQ{$Key};

            # replace \n with <br>
            $FAQ{$Key} =~ s/\n/<br\/>\n/g;

            $FoundNewline = 1;
        }
        next ID if !$FoundNewline;

        # update FAQ data
        $Self->{FAQObject}->FAQUpdate(
            %FAQ,
            UserID => 1,
        );
    }

    return 1;
}

=item _GroupAdd()

add a group

    my $Result = $CodeObject->_GroupAdd(
        Name        => 'the-group-name',
        Description => 'The group description.',
    );

=cut

sub _GroupAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(Name Description)) {
        if ( !$Param{$Argument} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # get valid list
    my %ValidList = $Self->{ValidObject}->ValidList(
        UserID => 1,
    );
    my %ValidListReverse = reverse %ValidList;

    # check if group already exists
    my $GroupID = $Self->{GroupObject}->GroupLookup(
        Group  => $Param{Name},
        UserID => 1,
    );

    # reactivate the group
    if ($GroupID) {

        # get current group data
        my %GroupData = $Self->{GroupObject}->GroupGet(
            ID     => $GroupID,
            UserID => 1,
        );

        # reactivate group
        $Self->{GroupObject}->GroupUpdate(
            %GroupData,
            ValidID => $ValidListReverse{valid},
            UserID  => 1,
        );

        return 1;
    }

    # add the group
    else {
        return if !$Self->{GroupObject}->GroupAdd(
            Name    => $Param{Name},
            Comment => $Param{Description},
            ValidID => $ValidListReverse{valid},
            UserID  => 1,
        );
    }

    # lookup the new group id
    my $NewGroupID = $Self->{GroupObject}->GroupLookup(
        Group  => $Param{Name},
        UserID => 1,
    );

    # add user root to the group
    $Self->{GroupObject}->GroupMemberAdd(
        GID        => $NewGroupID,
        UID        => 1,
        Permission => {
            ro        => 1,
            move_into => 1,
            create    => 1,
            owner     => 1,
            priority  => 1,
            rw        => 1,
        },
        UserID => 1,
    );

    return 1;
}

=item _GroupDeactivate()

deactivate a group

    my $Result = $CodeObject->_GroupDeactivate(
        Name => 'the-group-name',
    );

=cut

sub _GroupDeactivate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Name} ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => 'Need Name!',
        );
        return;
    }

    # lookup group id
    my $GroupID = $Self->{GroupObject}->GroupLookup(
        Group => $Param{Name},
    );

    return if !$GroupID;

    # get valid list
    my %ValidList = $Self->{ValidObject}->ValidList(
        UserID => 1,
    );
    my %ValidListReverse = reverse %ValidList;

    # get current group data
    my %GroupData = $Self->{GroupObject}->GroupGet(
        ID     => $GroupID,
        UserID => 1,
    );

    # deactivate group
    $Self->{GroupObject}->GroupUpdate(
        %GroupData,
        ValidID => $ValidListReverse{invalid},
        UserID  => 1,
    );

    return 1;
}

=item _LinkDelete()

delete all existing links to faq articles

    my $Result = $CodeObject->_LinkDelete();

=cut

sub _LinkDelete {
    my ( $Self, %Param ) = @_;

    # get all faq article ids
    my @FAQIDs = ();
    $Self->{DBObject}->Prepare(
        SQL => 'SELECT id FROM faq_item'
    );
    while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
        push @FAQIDs, $Row[0];
    }
    return if !@FAQIDs;

    # delete the faq article links
    for my $FAQID (@FAQIDs) {
        $Self->{LinkObject}->LinkDeleteAll(
            Object => 'FAQ',
            Key    => $FAQID,
            UserID => 1,
        );
    }

    return 1;
}

1;

=back

=head1 TERMS AND CONDITIONS

This Software is part of the OTRS project (http://otrs.org/).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (GPL). If you
did not receive this file, see http://www.gnu.org/licenses/gpl-2.0.txt.

=cut

=head1 VERSION

$Revision: 1.11 $ $Date: 2010-11-22 14:35:36 $

=cut
