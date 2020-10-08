
import time
import subprocess

# create a subdirectory based on a tag and current time
def createdir_ts (path, tag):

    ts = str (time.time ())
    subdir = path + '/' + tag + ts

    subprocess.run (["mkdir", subdir])
    return subdir


# truncate all files in dir with the given prefix
def truncate_files (dir, prefix):

    files_bytes = subprocess.check_output (["ls", dir])

    # get files in the form: [ "file1", "file2"..]
    files = files_bytes.decode('utf-8').strip('\n').split('\n')

    for file in files:
        if file.startswith (prefix):
            filename = dir + '/' + file
            subprocess.run (["truncate", "--size", str(0), filename])

# directory long-listing output to file
# dirlist is a list of directories, not necessarily unique
def list_files (dirlist, output_file):

    dirset = set ()
    ls_dirs = ""
    for dir in dirlist:
        if dir not in dirset:
            dirset.add (dir)
            if not ls_dirs:
                ls_dirs = dir
            else:
                ls_dirs = ls_dirs + ' ' + dir

    with open (output_file, 'w') as fh:
        subprocess.run (["ls", "-l", ls_dirs], stdout=fh)

