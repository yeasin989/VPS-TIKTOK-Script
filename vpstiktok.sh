#!/bin/bash

set -e

echo "==== TikTok Video Host VPS Setup ===="

# 1. Install Apache, PHP, FFmpeg
echo "[1/6] Installing Apache, PHP, FFmpeg..."
sudo apt update
sudo apt install -y apache2 php libapache2-mod-php ffmpeg

# 2. Create 'videos' folder in web root
echo "[2/6] Creating /var/www/html/videos..."
sudo mkdir -p /var/www/html/videos
sudo chmod 777 /var/www/html/videos

# 3. Deploy PHP files

cd /var/www/html

# admin.php
sudo tee admin.php > /dev/null <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Video Upload Admin</title>
</head>
<body>
    <h2>Upload Video</h2>
    <form action="upload.php" method="post" enctype="multipart/form-data">
        Select video to upload:<br>
        <input type="file" name="video" accept="video/*" required><br><br>
        <input type="submit" value="Upload Video">
    </form>
    <hr>
    <h3>Uploaded Videos</h3>
    <ul>
    <?php
    $files = array_diff(scandir("videos/"), array('..', '.'));
    foreach($files as $file) {
        echo "<li><a href='videos/$file' target='_blank'>$file</a></li>";
    }
    ?>
    </ul>
</body>
</html>
EOF

# upload.php
sudo tee upload.php > /dev/null <<'EOF'
<?php
$target_dir = "videos/";
$original_name = basename($_FILES["video"]["name"]);
$target_file = $target_dir . time() . "_" . preg_replace('/[^a-zA-Z0-9_\-\.]/','_', $original_name);
$uploadOk = 1;
$videoFileType = strtolower(pathinfo($target_file,PATHINFO_EXTENSION));

// Check video file type
$allowed = array('mp4','mov','webm','avi','mkv');
if(!in_array($videoFileType, $allowed)){
    echo "Sorry, only mp4, mov, webm, avi, mkv files are allowed.";
    $uploadOk = 0;
}

if ($uploadOk && move_uploaded_file($_FILES["video"]["tmp_name"], $target_file)) {
    // Optional: FFmpeg compress after upload
    $compressed_file = $target_dir . "compressed_" . time() . "." . $videoFileType;
    $cmd = "ffmpeg -i \"$target_file\" -vf \"scale='min(720,iw)':-2\" -b:v 1M -c:a copy \"$compressed_file\" -y";
    exec($cmd);
    if (file_exists($compressed_file)) {
        unlink($target_file); // Remove original
        rename($compressed_file, $target_file); // Use compressed as main
        echo "Upload and compression successful.<br>";
    } else {
        echo "Upload successful (compression skipped).<br>";
    }
    echo "<a href='admin.php'>Back</a>";
} else {
    echo "Sorry, there was an error uploading your file.";
}
?>
EOF

# videos.php
sudo tee videos.php > /dev/null <<'EOF'
<?php
$dir = "videos/";
$files = array_diff(scandir($dir), array('..', '.'));
$videos = [];
foreach($files as $file) {
    if (preg_match('/\.(mp4|mov|webm|avi|mkv)$/i', $file)) {
        $videos[] = (isset($_SERVER['HTTPS']) ? 'https://' : 'http://') . $_SERVER['HTTP_HOST'] . "/videos/" . $file;
    }
}
header('Content-Type: application/json');
echo json_encode(array_values($videos));
?>
EOF

# 4. Set permissions
echo "[4/6] Setting permissions..."
sudo chown -R www-data:www-data /var/www/html/
sudo chmod -R 755 /var/www/html/
sudo chmod 777 /var/www/html/videos

# 5. Restart Apache
echo "[5/6] Restarting Apache..."
sudo systemctl restart apache2

# 6. Print info
echo "[6/6] Setup complete!"
echo "--------------------------------------"
echo "Admin panel:   http://YOUR_SERVER_IP/admin.php"
echo "Video upload:  http://YOUR_SERVER_IP/upload.php"
echo "Video API:     http://YOUR_SERVER_IP/videos.php"
echo "Videos dir:    /var/www/html/videos/"
echo "--------------------------------------"
echo "Upload videos from the admin panel."
echo "If you want HTTPS, set up SSL (e.g., with Let's Encrypt)."

echo "==== ALL DONE ===="
