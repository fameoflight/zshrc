import subprocess
from os import path


def get_changed_files():
    files = subprocess.Popen(["git", "diff", "--name-only", "origin/master..."], stdout=subprocess.PIPE).communicate()[0]

    return [f.strip() for f in files.split() if f]


def get_test_files_app(in_dir, app_name):

    if app_name:
        app_dir = path.join(in_dir, app_name)
    else:
        app_dir = in_dir

    files = subprocess.Popen(["find", app_dir, "-name", 'test_*.py'], stdout=subprocess.PIPE).communicate()[0]

    return [f.strip() for f in files.split() if f]


def is_master():
    branch_name = subprocess.Popen(["git", "rev-parse", "--abbrev-ref", "HEAD"], stdout=subprocess.PIPE).communicate()[0]

    branch_name = branch_name.strip()

    return branch_name in ["master", "origin/master"]


def get_test_files():
    if is_master():
        test_files = get_test_files_app("app", None)
    else:
        changed_files = get_changed_files()

        app_files = [f for f in changed_files if f.startswith("app/")]

        app_names = set([f.split("/")[1] for f in app_files])

        test_files = []

        for app_name in app_names:
            test_files.extend(get_test_files_app("app", app_name))

    return list(set(test_files))

if __name__ == '__main__':
    app_dir = "app"

    test_files = get_test_files()

    cleaned_files = []

    for f in test_files:
        if f.startswith("app/"):
            f = "./" + f[4:]

        cleaned_files.append(f)

    print "\n".join(cleaned_files)
