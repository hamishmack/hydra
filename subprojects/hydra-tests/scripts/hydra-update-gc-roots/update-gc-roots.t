use feature 'unicode_strings';
use strict;
use warnings;
use Setup;
use Test2::V0;

my $ctx = test_context();
my $builds = $ctx->makeAndEvaluateJobset(
    expression => "one-job.nix",
    build => 1
);

subtest "Updating GC roots" => sub {
    my ($res, $stdout, $stderr) = $ctx->capture_cmd(5, "hydra-update-gc-roots");
    is($res, 0, "hydra-update-gc-roots should exit zero");
    if ($res != 0) {
        print "gc roots stdout: $stdout\n";
        print "gc roots stderr: $stderr\n";
    }
};

subtest "Builds of a disabled project are not kept" => sub {
    my ($build) = values %$builds;
    my $jobset = $build->jobset;
    $jobset->project->update({ enabled => 0 });

    my ($res, $stdout, $stderr) = $ctx->capture_cmd(5, "hydra-update-gc-roots");
    is($res, 0, "hydra-update-gc-roots should exit zero");
    like($stderr, qr/skipping disabled jobset \Q${\$jobset->get_column('project')}:${\$jobset->name}\E/,
        "a jobset of a disabled project is skipped even though it is not hidden");
};

subtest "A closed pull request's jobset is dropped at once, other disabled jobsets after a week" => sub {
    my $project = $ctx->makeJobset(expression => "one-job.nix")->{project};
    my %common = (
        type => 0,
        nixexprinput => "jobs",
        nixexprpath => "one-job.nix",
        emailoverride => "",
        enabled => 0,
        lastcheckedtime => time(),
    );
    $project->jobsets->create({ %common, name => "pullrequest-42" });
    $project->jobsets->create({ %common, name => "release-1" });
    $project->jobsets->create({ %common, name => "release-0", lastcheckedtime => time() - 8 * 24 * 3600 });

    my ($res, $stdout, $stderr) = $ctx->capture_cmd(5, "hydra-update-gc-roots");
    is($res, 0, "hydra-update-gc-roots should exit zero");
    my $p = $project->name;
    like($stderr, qr/skipping disabled jobset \Q$p\E:pullrequest-42\n/,
        "a disabled pull-request jobset is skipped though it was checked just now");
    unlike($stderr, qr/skipping disabled jobset \Q$p\E:release-1\n/,
        "another recently disabled jobset keeps its week's grace");
    like($stderr, qr/skipping disabled jobset \Q$p\E:release-0\n/,
        "another jobset disabled for over a week is skipped");
};

done_testing;
