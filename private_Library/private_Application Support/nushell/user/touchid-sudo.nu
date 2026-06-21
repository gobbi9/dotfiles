# enable sudo touchID, this setting may be removed after every MacOS update
def enable-touchid-sudo [] {
    let sudo_pam = "/etc/pam.d/sudo"
    let touchid_line = "auth       sufficient     pam_tid.so"

    let contents = (sudo cat $sudo_pam)

    if ($contents | str contains "pam_tid.so") {
        print "✅ Touch ID for sudo is already enabled."
        return
    }

    print "🔧 Enabling Touch ID for sudo..."

    # Create backup
    sudo cp $sudo_pam $"($sudo_pam).backup"

    # Create updated content
    let new_contents = ($touchid_line + "\n" + $contents)

    # Write atomically through temp file
    let tmp = (mktemp)

    $new_contents | save -f $tmp

    sudo mv $tmp $sudo_pam

    print "✅ Touch ID enabled for sudo."
    print $"📦 Backup saved to ($sudo_pam).backup"
}
