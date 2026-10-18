CREATE OR REPLACE FUNCTION run_script(script_path TEXT) 
RETURNS TEXT AS $$
    my $cmd = $_[0];
    my $output = `$cmd 2>&1`; -- Executes the shell script
    return $output;
$$ LANGUAGE plperlu;
