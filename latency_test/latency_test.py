#!/usr/bin/env python3

import argparse
import yaml
import subprocess
from jinja2 import Environment, FileSystemLoader

parser = argparse.ArgumentParser ()
parser.add_argument ("-i", "--input_file", help="name of yaml file with run parameters") 

args = parser.parse_args ()

# create dict of input params
#
if args.input_file:
    yaml_input = open (args.input_file)
    input_params = yaml.safe_load (yaml_input)
    yaml_input.close ()
else:
    input_params = {}

if input_params is None:
    input_params = {}

# create dict of default params
#
yaml_input = open ('./defaults.yaml')
run_params = yaml.safe_load (yaml_input)
yaml_input.close ()

if run_params is None:
    run_params = {}

# update default params with input values to get run params
run_params.update (input_params)
run_params['etc_logfile'] = run_params['etc_dir'] + '/logfile'

for numjobs in run_params['numjobs_list']:

    run_params['seqw_numjobs'] = numjobs
    run_params['randrw_numjobs'] = numjobs

    file_loader = FileSystemLoader ('./templates')
    env = Environment (loader=file_loader, trim_blocks=True)
    template = env.get_template ('jobfile.j2')

    rendered_job = template.render (run_params)
    jobfile = run_params['output_dir'] + '/jobfile.' + str (numjobs) + '.fio'

    jobfile_out = open (jobfile, 'w')
    print (rendered_job, file = jobfile_out)
    jobfile_out.close ()

    fio_output_option = '--output=' + run_params['output_dir'] + \
        '/run.' + str (numjobs) + '.out'

    # run fio 
    subprocess.run (["fio", jobfile, fio_output_option])


