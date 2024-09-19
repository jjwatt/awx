# Controller Collections Green Thread Test

We need to be able to verify the functionality of the
ansible.controller collection by walking through common workflows that
a customer would execute with it, to ensure it works as
expected. These green thread tests should follow the established
definition:

https://handbook.eng.ansible.com/docs/Testing/Test-Definition/green-thread-tests

And should be as explicit as possible so that they can be used in
hackathons and testathons.

[!WARNING]
This Green Thread Test currently uses the Gateway
Collection to walk through common controller workflows because
`ansible.controller` will not work correctly in 2.5. Writes to things
like Organizations must go through Gateway.

# Green Thread Prerequisites
1. AAP installed
2. Admin credentials on AAP from step 1
3. You’ll need access to the collection (it hasn’t been published yet) by one of the following:
   - Read access on the aap-gateway repo
   - A tarball of the collection which you can drop into your system and use


# Green Thread Steps

1. Download awx with git
```shell
$ git clone -b 24.6.1 https://github.com/ansible/awx.git
```

2. Install ansible
```shell
$ sudo dnf install ansible
```

4. For now, you will need to use the Gateway Collection for performing Controller Collection tasks. Get the Gateway Collection as outlined in the Steps for using the gateway collection doc.
If you have access to the aap-gateway repo, you can use the requirements.yml provided in tools/controller_collection/requirements.yml
```shell
$ cd tools/controller_collection
$ ansible-galaxy install -r requirements.yml
```

If you do not have access to the aap-gateway repo, you need to obtain the collections file package (tarball–it will end in .tar.gz and install that
```shell
$ ansible-galaxy install collection <collection_name>.tar.gz
```

5. Once the collection is installed, run controller_green_thread test playbook
```shell
$ cd tools/controller_collection
$ ansible-playbook ./controller_green_thread.yml
```
