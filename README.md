DropVault
==========

DropVault is an iPad program that can display files stored in your
DropBox account that have been encrypted with a password. The password
is never stored in DropBox. Without the password, neither files nor
file names can be recovered from your DropBox account.

I wrote this program to "scratch an itch" -- I wanted to read
confidental documents on my iPad. The easiest way to get documents on
my iPad was through DropBox, but I didn't want to put confidential
information on a cloud service. 

My solution was to encrypt the documents on my PC before putting them
in my DropBox folder. This program would decrypt them on my iPad. It
works perfectly for my purposes. However, right now I have no plans to
make this program available on the App Store. To be a worthwhile App
Store program, it would take a lot more polish around the end-to-end
scenario (like desktop programs for Windows and Mac to do
encryption). I don't have time to work on that right now.

However, with the recent interest around DropBox security, I hope this
program will be useful to fellow programmers. I'd be thrilled if
somebody takes this and turns it into a polished program that makes
secure DropBox storage available to the masses.



How it works
------------------

DropVault uses a directory in your DropBox account called
**StrongBox** (yes, that was my earlier name for this project). When
you store a file in your StrongBox folder, you decrypt the file with
the AES128 algorithm and a randomly generated key. Store the file in
the StrongBox folder with a random file name that ends with the
extension **.dat**. 

At this point, *nobody* can read the file in the StrongBox file. Not
even yourself! To enable you to read it, create a *key* file. This
file contains the key you used to encrypt the file and the file name,
and **it** is encrypted with a password of your choosing. (Encryption
is again done using the AES128 algorithm, using the algorithm from RFC
2898 to derive the encryption key from your password).

Thus, armed with your password, you can recover the file name and
decryption key from the **.key** file.

For Windows machines, I have written PowerShell scripts that automate
the encryption process.

On the iPad, this DropVault program automates decryption. It assumes
that you use the same password to protect each **.key** file. You
enter your password when you launch DropVault, and from that point on
you can read each file just by tapping it.

License
========================

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

Notice
==========================

* This project contains code from [Google Toolbox for
  Mac](http://code.google.com/p/google-toolbox-for-mac/). Google
  Toolbox for Mac is covered by the Apache 2.0 License.  

* This project contains code from
  [OCMock](http://www.mulle-kybernetik.com/software/OCMock/). This
  code is covered under the following license:

    Copyright (c) 2004 - 2011 by Mulle Kybernetik. All rights reserved.

    Permission to use, copy, modify and distribute this software and
    its documentation is hereby granted, provided that both the
    copyright notice and this permission notice appear in all copies
    of the software, derivative works or modified versions, and any
    portions thereof, and that both notices appear in supporting
    documentation, and that credit is given to Mulle Kybernetik in all
    documents and publicity pertaining to direct or indirect use of
    this code or its derivatives.

    THIS IS EXPERIMENTAL SOFTWARE AND IT IS KNOWN TO HAVE BUGS, SOME
    OF WHICH MAY HAVE SERIOUS CONSEQUENCES. THE COPYRIGHT HOLDER
    ALLOWS FREE USE OF THIS SOFTWARE IN ITS "AS IS" CONDITION. THE
    COPYRIGHT HOLDER DISCLAIMS ANY LIABILITY OF ANY KIND FOR ANY
    DAMAGES WHATSOEVER RESULTING DIRECTLY OR INDIRECTLY FROM THE USE
    OF THIS SOFTWARE OR OF ANY DERIVATIVE WORK.

* This project uses an icon from [Glyphish](http://glyphish.com/),
  which is provided with a Creative Commons attribution license.
