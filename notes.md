Mobil programlama pedagojisinde yapılandırılmış arayüzler tasarlanırken sıkça vurgulanan bir prensip olarak, liste görünümlerinde kullanıcının asıl ihtiyacı olan bağlamsal metaveriye (başlık ve süre) doğrudan ulaşabilmesi kritik bir UX (Kullanıcı Deneyimi) standardıdır. Bu verilerin eklenti ve PWA üzerinde net bir şekilde görünmesi, kullanıcının "Yolculuğum 20 dakika, bu sürede hangi içeriği dinleyebilirim?" sorusunu doğrudan çözecektir.

Daha önce hazırladığınız `down.py` dosyasında `yt-dlp` komut satırı aracı ile başlık ve süre verilerini çoktan başarıyla çekmiştiniz. Şimdi bu mevcut mantığı, PWA ve eklenti arayüzüne taşımak için yapmanız gerekenler şunlardır:

### 1. Metaverinin Kaydedilmesi (Backend Veritabanı)

`yt-dlp` indirme işlemine başlamadan hemen önce videonun metaverisini çıkardığı için, veritabanınızdaki `items` tablosuna `duration` (süre) sütununu eklemelisiniz.

Arka planda (FastAPI tarafında) indirme kuyruğu başladığında, `yt-dlp`'den dönen `info_dict` objesi üzerinden bu verileri yakalayıp veritabanını güncelleyebilirsiniz:

```python
# Backend: İndirme işlemi başladığında metaveriyi yakalama
with yt_dlp.YoutubeDL(ydl_opts) as ydl:
    # İndirmeden önce bilgileri çekiyoruz
    info_dict = ydl.extract_info(url, download=False)
    
    video_title = info_dict.get('title', 'Bilinmeyen Başlık')
    
    # Süreyi saniye cinsinden alıp formatlayabiliriz (Örn: "14:05")
    duration_seconds = info_dict.get('duration', 0)
    minutes, seconds = divmod(duration_seconds, 60)
    formatted_duration = f"{minutes}:{seconds:02d}"
    
    # Veritabanında başlık ve süreyi güncelle
    update_item_metadata(db_session, item_id, title=video_title, duration=formatted_duration)
    
    # Sonrasında asıl indirmeyi başlat
    ydl.download([url])

```

### 2. Eklenti ve PWA Arayüzünde Gösterim (Frontend)

PWA spesifikasyonlarınızda bahsettiğiniz "Item Card" (Öğe Kartı) yapısına, başlık ve süreyi barındıran temiz bir görsel hiyerarşi eklemeliyiz. React tarafında bu bileşeni şu şekilde güncelleyebilirsiniz:

```jsx
// React Component: Oynatma Listesi Öğe Kartı
function PlaylistItem({ item, onDelete, onPlay }) {
  return (
    <div className="playlist-item-card flex justify-between items-center p-4 border-b">
      
      {/* Sol Kısım: Başlık, Süre ve Durum */}
      <div className="flex-1 min-w-0">
        <h4 className="font-bold text-lg truncate" title={item.title}>
          {item.title || "Video Başlığı Bekleniyor..."}
        </h4>
        
        <div className="flex items-center mt-1 text-sm text-gray-500">
          {/* Süre Rozeti */}
          <span className="bg-gray-200 rounded px-2 py-1 mr-2 font-mono">
            ⏱️ {item.duration || "--:--"}
          </span>
          
          {/* Önceki adımda konuştuğumuz Durum Rozeti */}
          <ProgressBadge status={item.status} />
          
          {/* Dinlendi Bilgisi */}
          {item.is_listened && (
            <span className="text-green-600 ml-2">✓ Dinlendi</span>
          )}
        </div>
      </div>

      {/* Sağ Kısım: Aksiyon Butonları */}
      <div className="flex items-center space-x-3 ml-4">
        {item.status === 'ready' && (
          <button onClick={() => onPlay(item.id)} className="text-blue-500">
            ▶️ Dinle
          </button>
        )}
        <button onClick={() => onDelete(item.id)} className="text-red-500 hover:text-red-700">
          🗑️ Sil
        </button>
      </div>
      
    </div>
  );
}

```

Bu yapı ile oynatma listesini açtığınızda her videonun adını ve süresini (Örn: **14:05**) doğrudan görebilecek, sağ taraftaki silme butonuyla listeyi anında temizleyebilecek ve "Dinlendi" işaretiyle nerede kaldığınızı kolayca takip edebileceksiniz.


