import cv2
import numpy as np
import firebase_admin
from firebase_admin import credentials
from firebase_admin import db
import time
import datetime
import threading
from flask import Flask, Response # <-- FLASK KUTUPHANESI

# --- AYARLAR ---
FIREBASE_URL = '' 

# YESIL OK TERS TARAFI GOSTERIYORSA BUNU True YAP
SAYIM_YONUNU_TERS_CEVIR = False 

ROTATE_CAMERA = False 
FRAME_WIDTH = 300       
SKIP_FRAMES = 2         
CONFIDENCE_LIMIT = 0.4 

# --- FLASK AYARLARI ---
app = Flask(__name__)
outputFrame = None
lock = threading.Lock()

# --- FIREBASE BAĞLANTISI ---
if not firebase_admin._apps:
    cred = credentials.Certificate("serviceAccountKey.json")
    firebase_admin.initialize_app(cred, {'databaseURL': FIREBASE_URL})

ref_home = db.reference('home')
ref_logs = db.reference('logs')

# --- GLOBAL DEGISKENLER ---
kapi_acik = True
prev_kapi_acik = True
last_detections = None 

# --- DINLEYICI ---
def veritabani_dinle(event):
    global kapi_acik
    try:
        yeni_deger = None
        if event.path == '/' and isinstance(event.data, dict):
            yeni_deger = event.data.get('door_status')
        elif event.path == '/door_status':
            yeni_deger = event.data
        if yeni_deger is not None:
            str_deger = str(yeni_deger).lower()
            kapi_acik = (str_deger == 'true' or str_deger == '1')
    except:
        pass

try:
    ref_home.listen(veritabani_dinle)
except:
    pass

def log_to_firebase(p_total, p_in, p_out):
    try:
        now = datetime.datetime.now()
        ref_logs.push({
            'date': now.strftime("%Y-%m-%d"),
            'time': now.strftime("%H:%M:%S"),
            'timestamp': int(time.time()),
            'event': 'stop_completed',
            'session_in': p_in,
            'session_out': p_out,
            'new_total_passenger': p_total
        })
        print(f"[LOG] Durak verisi kaydedildi. Yeni Toplam: {p_total}")
    except Exception as e:
        print(f"[HATA] Log gonderilemedi: {e}")

# --- ISLEM FONKSIYONU (Arka Planda Calisacak) ---
def detect_motion():
    global kapi_acik, prev_kapi_acik, outputFrame, lock, last_detections

    CLASSES = ["background", "aeroplane", "bicycle", "bird", "boat",
        "bottle", "bus", "car", "cat", "chair", "cow", "diningtable",
        "dog", "horse", "motorbike", "person", "pottedplant", "sheep",
        "sofa", "train", "tvmonitor"]

    print("[INFO] Model yukleniyor...")
    net = cv2.dnn.readNetFromCaffe("MobileNetSSD_deploy.prototxt", "MobileNetSSD_deploy.caffemodel")

    try:
        cap = cv2.VideoCapture(0, cv2.CAP_V4L2)
        cap.set(cv2.CAP_PROP_FOURCC, cv2.VideoWriter_fourcc('M', 'J', 'P', 'G'))
        cap.set(cv2.CAP_PROP_FPS, 30)
    except:
        cap = cv2.VideoCapture(0)

    time.sleep(1.0)

    # --- SAYAÇLAR ---
    session_entered = 0 
    session_exited = 0
    tracked_objects = {} 
    next_object_id = 0
    total_frames = 0 
    last_detections = None

    print("[INFO] CANLI YAYINLI SISTEM BASLATILDI.")

    while True:
        
        # --- DURUM 1: KAPI KAPANDI MI? (Hesaplama Ani) ---
        if not kapi_acik and prev_kapi_acik:
            print("[BILGI] Kapi Kapandi! Hesaplamalar yapiliyor...")
            
            try:
                # 1. Veritabanindan eski toplami cek
                snapshot = ref_home.get()
                current_total = 0
                if snapshot and isinstance(snapshot, dict):
                    current_total = snapshot.get('passenger_count', 0)
                
                # 2. Yeni toplami hesapla
                net_change = session_entered - session_exited
                new_total = current_total + net_change
                if new_total < 0: new_total = 0
                
                print(f"Hesap: {current_total} + ({session_entered} - {session_exited}) = {new_total}")
                
                # 3. Veritabanini guncelle ve sifirla
                ref_home.update({
                    'passenger_count': new_total,
                    'entered': 0,
                    'exited': 0
                })
                
                # 4. Logla
                log_to_firebase(new_total, session_entered, session_exited)
                
            except Exception as e:
                print(f"[HATA] Guncelleme hatasi: {e}")
            
            # 5. Yerel degiskenleri sifirla
            session_entered = 0
            session_exited = 0
            prev_kapi_acik = False

        if kapi_acik:
            prev_kapi_acik = True

        # --- DURUM 2: UYKU MODU (Kapi Kapali) ---
        if not kapi_acik:
            ret, _ = cap.read() # Buffer temizle
            
            # Ekrana Siyah Kare + Yazi Gonder (Yayin Kopmasin)
            blank_frame = np.zeros((225, FRAME_WIDTH, 3), dtype=np.uint8)
            cv2.putText(blank_frame, "UYKU MODU (Kapi Kapali)", (20, 110), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 255), 1)
            
            with lock:
                outputFrame = blank_frame.copy()
            
            time.sleep(0.5) # Islemciyi dinlendir
            continue 

        # --- DURUM 3: KAPI ACIK (Aktif Sayim) ---
        ret, frame = cap.read()
        if not ret:
            continue
        
        total_frames += 1
        frame = cv2.resize(frame, (FRAME_WIDTH, 225)) 
        if ROTATE_CAMERA:
            frame = cv2.rotate(frame, cv2.ROTATE_90_CLOCKWISE)

        (h, w) = frame.shape[:2]
        line_pos = int(w / 2)
        cv2.line(frame, (line_pos, 0), (line_pos, h), (0, 255, 255), 2)

        # --- TESPIT ---
        if total_frames % SKIP_FRAMES == 0:
            blob = cv2.dnn.blobFromImage(frame, 0.007843, (300, 300), 127.5)
            net.setInput(blob)
            last_detections = net.forward()
        
        detections = last_detections
        current_centers = [] 

        if detections is not None:
            for i in range(detections.shape[2]):
                confidence = detections[0, 0, i, 2]
                if confidence > CONFIDENCE_LIMIT:
                    idx = int(detections[0, 0, i, 1])
                    if CLASSES[idx] != "person": continue

                    box = detections[0, 0, i, 3:7] * np.array([w, h, w, h])
                    (startX, startY, endX, endY) = box.astype("int")
                    centerX = int((startX + endX) / 2)
                    current_centers.append(centerX)
                    
                    cv2.rectangle(frame, (startX, startY), (endX, endY), (0, 255, 0), 1)

        # --- TAKIP VE SAYIM ---
        if total_frames % SKIP_FRAMES == 0:
            new_tracked_objects = {}
            for cx in current_centers:
                matched_id = None
                min_dist = 9999
                for obj_id, data in tracked_objects.items():
                    last_pos = data['history'][-1]
                    dist = abs(cx - last_pos)
                    if dist < 60:
                        if dist < min_dist:
                            min_dist = dist
                            matched_id = obj_id
                
                if matched_id is not None:
                    history = tracked_objects[matched_id]['history']
                    history.append(cx)
                    if len(history) > 10: history.pop(0)
                    new_tracked_objects[matched_id] = {'history': history, 'missing': 0}
                    
                    if len(history) >= 2:
                        first_pos = history[0]
                        last_pos = history[-1]
                        
                        if first_pos > line_pos and last_pos < line_pos: # Sagdan Sola
                            if 'counted' not in tracked_objects[matched_id]:
                                if not SAYIM_YONUNU_TERS_CEVIR: 
                                    session_entered += 1
                                    try: ref_home.update({'entered': session_entered})
                                    except: pass
                                    print(f"GIRIS (IN)! Anlik: {session_entered}")
                                else: 
                                    session_exited += 1
                                    try: ref_home.update({'exited': session_exited})
                                    except: pass
                                    print(f"CIKIS (OUT)! Anlik: {session_exited}")
                                new_tracked_objects[matched_id]['counted'] = True

                        elif first_pos < line_pos and last_pos > line_pos: # Soldan Saga
                            if 'counted' not in tracked_objects[matched_id]:
                                if not SAYIM_YONUNU_TERS_CEVIR: 
                                    session_exited += 1
                                    try: ref_home.update({'exited': session_exited})
                                    except: pass
                                    print(f"CIKIS (OUT)! Anlik: {session_exited}")
                                else: 
                                    session_entered += 1
                                    try: ref_home.update({'entered': session_entered})
                                    except: pass
                                    print(f"GIRIS (IN)! Anlik: {session_entered}")
                                new_tracked_objects[matched_id]['counted'] = True

                    if 'counted' in tracked_objects[matched_id]:
                        new_tracked_objects[matched_id]['counted'] = True
                    del tracked_objects[matched_id]
                else:
                    new_tracked_objects[next_object_id] = {'history': [cx], 'missing': 0}
                    next_object_id += 1
            
            for obj_id, data in tracked_objects.items():
                if data['missing'] < 5:
                    data['missing'] += 1
                    new_tracked_objects[obj_id] = data
            tracked_objects = new_tracked_objects

        # --- EKRAN CIZIMLERI ---
        if SAYIM_YONUNU_TERS_CEVIR:
            cv2.arrowedLine(frame, (60, 20), (20, 20), (0, 255, 0), 2)
            cv2.putText(frame, "IN", (20, 40), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 0), 2)
        else:
            cv2.arrowedLine(frame, (w-60, 20), (w-20, 20), (0, 255, 0), 2) 
            cv2.putText(frame, "IN", (w-55, 40), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 0), 2)

        cv2.putText(frame, f"S_IN: {session_entered}", (10, 20), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 0), 1)
        cv2.putText(frame, f"S_OUT: {session_exited}", (10, 40), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 0, 255), 1)
        
        # --- FLASK GORUNTU GUNCELLEME ---
        with lock:
            outputFrame = frame.copy()

# --- FLASK SUNUCU ---
def generate():
    global outputFrame, lock
    while True:
        with lock:
            if outputFrame is None:
                continue
            (flag, encodedImage) = cv2.imencode(".jpg", outputFrame)
            if not flag:
                continue
        yield(b'--frame\r\n' b'Content-Type: image/jpeg\r\n\r\n' + 
            bytearray(encodedImage) + b'\r\n')

@app.route("/video_feed")
def video_feed():
    return Response(generate(), mimetype = "multipart/x-mixed-replace; boundary=frame")

# --- BASLATMA ---
if __name__ == '__main__':
    t = threading.Thread(target=detect_motion)
    t.daemon = True
    t.start()
    
    # 0.0.0.0 = Tum cihazlara acik
    app.run(host="0.0.0.0", port=5000, debug=False, threaded=True, use_reloader=False)