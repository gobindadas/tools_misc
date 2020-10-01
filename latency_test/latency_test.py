#!/usr/bin/env python3

import argparse
import yaml
import time
import subprocess
import copy
from jinja2 import Environment, FileSystemLoader

# create a subdirectory based on a tag and current time
def createdir_ts (path, tag):

    ts = str (time.time ())
    subdir = path + '/' + tag + ts

    subprocess.run (["mkdir", subdir])
    return subdir

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

# dirlist is a list of dict
dirlist = input_params.pop ('etcd_dirlist', [])
if dirlist is None:
    dirlist = []

# njobslist is a list of integers (numjobs)
njobslist = input_params.pop ('numjobs_list', [])
if njobslist is None:
    njobslist = []

i_outer = 0
for dir_dict in dirlist:

    if dir_dict is None:
        dir_dict = {}

    # make a copy of input params
    loop_params = copy.deepcopy (input_params)

    # tag is optional
    if 'tag' in dir_dict:
        run_tag = dir_dict['tag']
    else:
        run_tag = 'etcd-config-' + str (i_outer)

    # dir is not optional
    loop_params['etc_dir'] = dir_dict['dir']

    print (f'test {run_tag}')

    i_inner = 0
    for numjobs in njobslist:

        print (f'iteration with numjobs = {numjobs}')

        loop_params['seqw_numjobs'] = numjobs
        loop_params['randrw_numjobs'] = numjobs

        # derive file sizes
        if 'seqw_datatset_sz_gb' in loop_params:
            loop_params['seqw_fsz_gb'] = \
                loop_params['seqw_datatset_sz_gb'] / numjobs

        if 'randrw_datatset_sz_gb' in loop_params:
            loop_params['randrw_fsz_gb'] = \
                loop_params['randrw_datatset_sz_gb'] / numjobs

        # update default params with input values to get run params
        run_params.update (loop_params)

        # set derived parameters
        run_params['etc_logfile'] = run_params['etc_dir'] + '/logfile'

        file_loader = FileSystemLoader ('./templates')
        env = Environment (loader=file_loader, trim_blocks=True)
        template = env.get_template ('jobfile.j2')

        rendered_job = template.render (run_params)

        # create a directory for run
        if i_outer == 0 and i_inner == 0:
            run_outdir = createdir_ts (run_params['output_dir'], 'run_')

        if i_inner == 0:
            output_dir = run_outdir + '/' + run_tag
            subprocess.run (["mkdir", "-p" , output_dir])

        # fio jobfile
        jobfile = output_dir + '/jobfile.' + str (numjobs) + '.fio'

        with open (jobfile, 'w') as jobfile_out:
            print (rendered_job, file = jobfile_out)

        fio_output_option = '--output=' + output_dir + \
            '/run.' + str (numjobs) + '.out'

        # run fio 
        subprocess.check_output (["fio", jobfile, fio_output_option])
        i_inner += 1

    i_outer += 1

