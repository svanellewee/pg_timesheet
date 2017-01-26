import yaml
from email.mime.application import MIMEApplication
from email.mime.multipart import MIMEMultipart

import smtplib
from os.path import basename
from email.mime.text import MIMEText
from email.utils import COMMASPACE, formatdate


def send_mail(username, password, recipient, subject, body, files=None):
    assert isinstance(recipient, list)
    gmail_user = username
    gmail_pwd = password

    msg = MIMEMultipart()
    msg['From'] = username
    msg['To'] = COMMASPACE.join(recipient)
    msg['Date'] = formatdate(localtime=True)
    msg['Subject'] = subject

    msg.attach(MIMEText(body))

    for f in files or []:
        with open(f, "rb") as fil:
            part = MIMEApplication(
                fil.read(),
                Name=basename(f)
            )
            part['Content-Disposition'] = 'attachment; filename="%s"' % basename(f)
            msg.attach(part)

    smtp = smtplib.SMTP_SSL("smtp.gmail.com", 465)
    smtp.ehlo()
    smtp.login(gmail_user, gmail_pwd)
    smtp.sendmail(gmail_user, recipient, msg.as_string())
    smtp.close()

import random
import sys
import datetime
print sys.argv
with open(".credentials.yml") as config_file:
    config = yaml.load(config_file.read())
    username, password, recipient = config['email']['username'], config['email']['password'], config['email']['recipients'][0]

    subject = "Time sheet at: "+datetime.datetime.now().isoformat()
    send_mail(username,
              password,
              config['email']['recipients'],
              "Today's timesheet",
              random.choice(["Timesheet for today {}".format(subject),
                             "Today's timesheet {}".format(subject),]),
              sys.argv[1:])
