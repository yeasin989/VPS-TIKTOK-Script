#!/bin/bash

set -e

# Find external IP
YOUR_SERVER_IP=$(curl -s https://api.ipify.org)

echo "==== TikTok Video Host VPS Setup (Pro Admin Panel) ===="

sudo apt update
sudo apt install -y apache2 php libapache2-mod-php ffmpeg

PHPVER=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')
PHPINI="/etc/php/${PHPVER}/apache2/php.ini"
sudo sed -i 's/^upload_max_filesize\s*=.*/upload_max_filesize = 500M/' "$PHPINI"
sudo sed -i 's/^post_max_size\s*=.*/post_max_size = 500M/' "$PHPINI"
sudo sed -i 's/^max_execution_time\s*=.*/max_execution_time = 600/' "$PHPINI"
sudo systemctl restart apache2

sudo mkdir -p /var/www/html/videos
sudo chmod 777 /var/www/html/videos
sudo chown -R www-data:www-data /var/www/html/videos

cd /var/www/html

# admin.php
sudo tee admin.php > /dev/null <<'EOF'
<?php
function human_filesize($bytes, $decimals = 2) {
  $size = array('B','KB','MB','GB','TB','PB');
  $factor = floor((strlen($bytes) - 1) / 3);
  return sprintf("%.{$decimals}f", $bytes / pow(1024, $factor)) . @$size[$factor];
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Video Admin | TikTok Host</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <link href="https://fonts.googleapis.com/css?family=Roboto:500,700&display=swap" rel="stylesheet">
    <style>
        body {
            margin: 0;
            background: #181A20;
            font-family: 'Roboto', Arial, sans-serif;
            color: #f1f1f1;
        }
        .container {
            max-width: 620px;
            margin: 40px auto 30px auto;
            background: #23242b;
            border-radius: 18px;
            box-shadow: 0 0 20px #0007;
            padding: 36px 28px 22px 28px;
        }
        h1 {
            text-align: center;
            margin-bottom: 18px;
            font-weight: 700;
            font-size: 2.2em;
            color: #16fff8;
            letter-spacing: 1px;
        }
        .success, .error {
            padding: 10px 0;
            margin-bottom: 8px;
            border-radius: 8px;
            text-align: center;
            font-size: 1.07em;
        }
        .success {background: #08d9b6; color: #181A20;}
        .error   {background: #f14545; color: #fff;}
        .upload-form {
            display: flex;
            flex-wrap: wrap;
            gap: 10px;
            align-items: center;
            background: #222429;
            border-radius: 12px;
            padding: 18px 14px;
            margin-bottom: 26px;
        }
        .upload-form label {
            min-width: 85px;
            font-size: 1em;
            color: #b3b3c3;
        }
        .upload-form input[type="file"], .upload-form input[type="text"] {
            flex: 1;
            background: #222429;
            color: #eee;
            border: 1px solid #444;
            border-radius: 6px;
            padding: 8px;
            font-size: 1em;
        }
        .upload-form input[type="submit"] {
            background: linear-gradient(90deg, #16fff8 0%, #1289a7 100%);
            color: #23242b;
            font-weight: bold;
            border: none;
            border-radius: 6px;
            padding: 9px 22px;
            cursor: pointer;
            font-size: 1.08em;
            transition: background 0.18s;
            margin-top: 5px;
        }
        .upload-form input[type="submit"]:hover {
            background: linear-gradient(90deg, #1289a7 0%, #16fff8 100%);
            color: #fff;
        }
        .videos-list {
            margin: 20px 0 0 0;
        }
        .videos-list li {
            background: #181A20;
            display: flex;
            align-items: center;
            justify-content: space-between;
            padding: 11px 12px;
            border-radius: 10px;
            margin-bottom: 10px;
            box-shadow: 0 2px 10px #0004;
            transition: background 0.13s;
        }
        .videos-list li:hover { background: #23242b;}
        .vid-info {
            flex: 1;
            display: flex;
            align-items: center;
            gap: 13px;
        }
        .vid-title {
            font-size: 1.06em;
            color: #16fff8;
            font-weight: 500;
            margin-right: 10px;
        }
        .vid-size {
            color: #c2f6ef;
            font-size: 0.95em;
            font-family: monospace;
            opacity: 0.7;
        }
        .vid-link {
            color: #8ad7ef;
            text-decoration: underline;
            font-size: 0.97em;
        }
        .delete-btn {
            color: #f14545;
            background: none;
            border: none;
            font-size: 1.45em;
            margin-left: 14px;
            cursor: pointer;
            transition: color 0.13s;
        }
        .delete-btn:hover {
            color: #fff;
            text-shadow: 0 0 6px #f14545aa;
        }
        @media (max-width: 480px) {
            .container {padding: 12px 3vw;}
            .upload-form label {font-size: 0.96em;}
            .vid-title {font-size: 1em;}
        }
        a.info-link {
            display: inline-block;
            margin: 12px auto 0 auto;
            color: #aafaf2;
            background: #1a202a;
            padding: 6px 18px;
            border-radius: 8px;
            text-decoration: none;
            text-align: center;
            font-size: 1.03em;
        }
        a.info-link:hover {background: #23242b;}
    </style>
</head>
<body>
<div class="container">
    <h1>Video Admin</h1>
    <?php
    if (isset($_GET['deleted'])) {
        echo "<div class='success'>Video deleted!</div>";
    }
    if (isset($_GET['error'])) {
        echo "<div class='error'>Error: File not found or cannot delete.</div>";
    }
    if (isset($_GET['uploaded'])) {
        echo "<div class='success'>Video uploaded successfully!</div>";
    }
    ?>
    <form class="upload-form" action="upload.php" method="post" enctype="multipart/form-data">
        <label for="title">Title:</label>
        <input type="text" name="title" id="title" maxlength="50" placeholder="Enter title or leave as filename">
        <label for="video">Video File:</label>
        <input type="file" name="video" accept="video/*" required>
        <input type="submit" value="Upload Video">
    </form>
    <h3 style="margin-top:14px;">Uploaded Videos</h3>
    <ul class="videos-list">
    <?php
    $meta_file = "videos/meta.json";
    if (file_exists($meta_file)) {
        $meta = json_decode(file_get_contents($meta_file), true);
    } else {
        $meta = [];
    }
    $files = array_diff(scandir("videos/"), array('..', '.', 'meta.json'));
    foreach($files as $file) {
        $filepath = "videos/$file";
        $size = human_filesize(filesize($filepath));
        $title = isset($meta[$file]['title']) && $meta[$file]['title'] ? htmlspecialchars($meta[$file]['title']) : $file;
        echo "<li>
                <div class='vid-info'>
                    <span class='vid-title'>{$title}</span>
                    <span class='vid-size'>{$size}</span>
                    <a class='vid-link' href='videos/".urlencode($file)."' target='_blank'>View</a>
                </div>
                <form method='get' action='delete.php' style='display:inline; margin:0;'>
                    <input type='hidden' name='file' value='".htmlspecialchars($file)."'>
                    <button class='delete-btn' title='Delete' onclick=\"return confirm('Delete this video?');\">&#128465;</button>
                </form>
              </li>";
    }
    ?>
    </ul>
    <a class="info-link" href="info.php" target="_blank">Check Server PHP Info</a>
</div>
</body>
</html>
EOF

# upload.php
sudo tee upload.php > /dev/null <<'EOF'
<?php
function update_title($file, $title) {
    $meta_file = "videos/meta.json";
    $meta = file_exists($meta_file) ? json_decode(file_get_contents($meta_file), true) : [];
    $meta[$file] = ['title' => $title];
    file_put_contents($meta_file, json_encode($meta, JSON_PRETTY_PRINT));
}

$target_dir = "videos/";
$original_name = basename($_FILES["video"]["name"]);
$video_title = isset($_POST['title']) && trim($_POST['title']) != '' ? trim($_POST['title']) : $original_name;
$target_file = $target_dir . time() . "_" . preg_replace('/[^a-zA-Z0-9_\-\.]/','_', $original_name);
$uploadOk = 1;
$videoFileType = strtolower(pathinfo($target_file, PATHINFO_EXTENSION));

// Check video file type
$allowed = array('mp4','mov','webm','avi','mkv');
if(!in_array($videoFileType, $allowed)){
    echo "Sorry, only mp4, mov, webm, avi, mkv files are allowed.";
    $uploadOk = 0;
}

// Limit file size to 500MB
if ($_FILES["video"]["size"] > 524288000) {
    echo "Sorry, your file is too large. Max allowed size is 500MB.";
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
    }
    // Store title
    update_title(basename($target_file), $video_title);
    header('Location: admin.php?uploaded=1');
    exit();
} else {
    echo "Sorry, there was an error uploading your file.";
}
?>
EOF

# delete.php
sudo tee delete.php > /dev/null <<'EOF'
<?php
if (isset($_GET['file'])) {
    $file = basename($_GET['file']);
    $videoPath = __DIR__ . '/videos/' . $file;
    $meta_file = __DIR__ . '/videos/meta.json';
    if (file_exists($videoPath) && is_file($videoPath)) {
        unlink($videoPath);
        // Remove from meta.json
        if (file_exists($meta_file)) {
            $meta = json_decode(file_get_contents($meta_file), true);
            if (isset($meta[$file])) {
                unset($meta[$file]);
                file_put_contents($meta_file, json_encode($meta, JSON_PRETTY_PRINT));
            }
        }
        header('Location: admin.php?deleted=1');
        exit();
    } else {
        header('Location: admin.php?error=1');
        exit();
    }
}
header('Location: admin.php');
exit();
?>
EOF

# videos.php
sudo tee videos.php > /dev/null <<'EOF'
<?php
$dir = "videos/";
$files = array_diff(scandir($dir), array('..', '.', 'meta.json'));
$videos = [];
$meta_file = $dir . "meta.json";
$meta = file_exists($meta_file) ? json_decode(file_get_contents($meta_file), true) : [];
foreach($files as $file) {
    if (preg_match('/\.(mp4|mov|webm|avi|mkv)$/i', $file)) {
        $title = isset($meta[$file]['title']) && $meta[$file]['title'] ? $meta[$file]['title'] : $file;
        $videos[] = [
            "url" => (isset($_SERVER['HTTPS']) ? 'https://' : 'http://') . $_SERVER['HTTP_HOST'] . "/videos/" . $file,
            "title" => $title
        ];
    }
}
header('Content-Type: application/json');
echo json_encode(array_values($videos));
?>
EOF

# info.php
sudo tee info.php > /dev/null <<'EOF'
<?php
phpinfo();
?>
EOF

sudo chown -R www-data:www-data /var/www/html/
sudo chmod -R 755 /var/www/html/
sudo chmod 777 /var/www/html/videos

sudo systemctl restart apache2

echo "--------------------------------------"
echo "Admin panel:   http://$YOUR_SERVER_IP/admin.php"
echo "Video upload:  http://$YOUR_SERVER_IP/upload.php"
echo "Video API:     http://$YOUR_SERVER_IP/videos.php"
echo "Info page:     http://$YOUR_SERVER_IP/info.php"
echo "Videos dir:    /var/www/html/videos/"
echo "--------------------------------------"
echo "Upload videos from the admin panel."
echo "Delete videos with the trash icon."
echo "Edit title on upload."
echo "Check server info at info.php."
echo "==== ALL DONE ===="
