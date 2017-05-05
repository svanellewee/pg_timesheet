import yaml
import dropbox
from dropbox.files import WriteMode
from dropbox.exceptions import ApiError, AuthError
import sys
import os

# Uploads contents of LOCALFILE to Dropbox
def backup(dbx, local_file, target_path):
    with open(local_file, 'rb') as f:
        # We use WriteMode=overwrite to make sure that the settings in the file
        # are changed on upload
        print("Uploading " + local_file + " to Dropbox as " + target_path + "...")
        try:
            dbx.files_upload(f.read(), target_path, mode=WriteMode('overwrite'))
        except ApiError as err:
            # This checks for the specific error where a user doesn't have
            # enough Dropbox space quota to upload this file
            if (err.error.is_path() and
                    err.error.get_path().error.is_insufficient_space()):
                sys.exit("ERROR: Cannot back up; insufficient space.")
            elif err.user_message_text:
                print(err.user_message_text)
                sys.exit()
            else:
                print(err)
                sys.exit()


def list_files(dbx, target_path, max_revisions=30):
    results = dbx.files_list_revisions(target_path, limit=max_revisions)
    for entry in results.entries:
        print(entry)


def main():
    with open(".credentials.yml") as config_file:
        config = yaml.load(config_file.read())
        token = config['upload']['token']
        target_path = config['upload']['target_path']

        dbx = dropbox.Dropbox(token)
        try:
            print(dbx.users_get_current_account())
        except AuthError as err:
            sys.exit("ERROR: Invalid token {}".format(err))

        local_file_path = sys.argv[1]
        file_name = os.path.basename(local_file_path)
        target = os.path.join(target_path, file_name)
        backup(dbx, local_file_path, target)
        list_files(dbx, target)

if __name__ == "__main__":
    main()
