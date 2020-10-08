#!/usr/bin/env python3

import argparse
import yaml
import subprocess
from jinja2 import Environment, FileSystemLoader
import util_functions

parser = argparse.ArgumentParser ()
parser.add_argument ("-i", "--input_file", help="name of yaml file with run parameters") 

args = parser.parse_args ()

# create dict of input params
#
if args.input_file:
    with open (args.input_file) as yaml_input:
        input_params = yaml.safe_load (yaml_input)
    if input_params is None:
        input_params = {}
else:
    input_params = {}

# create dict of default params
#
with open ('./defaults.yaml') as yaml_input:
    run_params = yaml.safe_load (yaml_input)
if run_params is None:
    run_params = {}

# update default params with input values to get run params
run_params.update (input_params)

# dirlist is a list of dict
dirlist = run_params.pop ('etcd_dirlist', [])
if dirlist is None:
    dirlist = []

# njobslist is a list of integers (numjobs)
njobslist = run_params.pop ('numjobs_list', [])
if njobslist is None:
    njobslist = []

run_outdir = util_functions.createdir_ts (run_params['output_dir'], 'run_')

i_outer = 0
for dir_dict in dirlist:

    if dir_dict is None:
        dir_dict = {}

    # tag is optional
    if 'tag' in dir_dict:
        run_tag = dir_dict['tag']
    else:
        run_tag = 'etcd-config-' + str (i_outer)

    # dir is not optional
    run_params['etc_dir'] = dir_dict['dir']

    # set derived parameters
    run_params['etc_logfile'] = run_params['etc_dir'] + '/logfile'

    # useful later to capture list of all files created
    all_dirs = [run_params['etc_dir'], run_params['seqw_dir'], \
        run_params['randrw_dir']]

    output_dir = run_outdir + '/' + run_tag
    subprocess.run (["mkdir", "-p" , output_dir])

    print (f'test {run_tag}')

    for numjobs in njobslist:

        print (f'iteration with numjobs = {numjobs}')

        run_params['seqw_numjobs'] = numjobs
        run_params['randrw_numjobs'] = numjobs

        # derive file sizes
        run_params['seqw_fsz_gb'] = \
            int (run_params['seqw_dataset_sz_gb'] / numjobs)

        run_params['randrw_fsz_gb'] = \
            int (run_params['randrw_dataset_sz_gb'] / numjobs)

        file_loader = FileSystemLoader ('./templates')
        env = Environment (loader=file_loader, trim_blocks=True)
        template = env.get_template ('jobfile.j2')

        rendered_job = template.render (run_params)

        # fio jobfile
        jobfile = output_dir + '/jobfile.' + str (numjobs) + '.fio'

        with open (jobfile, 'w') as jobfile_out:
            print (rendered_job, file = jobfile_out)

        fio_output_option = '--output=' + output_dir + \
            '/run.' + str (numjobs) + '.out'

        # run fio 
        subprocess.check_output (["fio", jobfile, fio_output_option])

        # capture file listing for validation
        ls_file = output_dir + '/ls_l.' + str (numjobs) 
        util_functions.list_files (all_dirs, ls_file)

        # truncate files
        util_functions.truncate_files (run_params['etc_dir'], \
            'logfile')
        util_functions.truncate_files (run_params['seqw_dir'], \
            run_params['seqw_prfx'])
        util_functions.truncate_files (run_params['randrw_dir'], \
            run_params['randrw_prfx'])

    i_outer += 1

