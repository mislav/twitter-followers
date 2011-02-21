# Twitter followers app

This web app processes incoming "{Person} is now following you on Twitter" emails from Twitter. It saves info about the user who follows you and shows a queue of new followers so you can decide which ones to block. It also gives you an Atom feed of your new followers.

![app screenshot](http://cl.ly/4j6x/Screen_shot_2011-02-20_at_9.22.31_PM.png)


## Configuration

See "config.yml". Either use environment variables, or create a "config.local.yml" (ignored from version control) where you can selectively override values for the machine where the app is running.


## Incoming email configuration

I forward my Twitter email notifications from my main email account to an address such as `mislav@example.com`. On the server for this domain, I configure postfix to save each email in a separate file and [Astrotrain][] to process them and send them to this app via HTTP POST.

The POST should be to the root URL ("/") and should contain the HTML part of the email in the `html` parameter and email headers in parameters such as `headers[x-twitterrecipientscreenname]=mislav`. This parameter scheme is the default in Astrotrain, so no extra configuration is necessary.

In "/etc/postfix/main.cf":

    myorigin = /etc/mailname
    mydestination = example.com, localhost.localdomain, localhost

    # the trailing slash is important here!
    # see man local(8) under "MAILBOX DELIVERY"
    mail_spool_directory = /var/mail/

Then, in Astrotrain "config.rb":

    Astrotrain::Message.queue_path = "/var/mail/mislav/new"
    Astrotrain::Message.archive_path = File.join(Astrotrain.root, 'archive')

[astrotrain]: https://github.com/entp/astrotrain
