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

done_testing;
