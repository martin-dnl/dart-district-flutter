import { useState } from "react";
import { useOutletContext } from "react-router-dom";
import { base44 } from "@/api/base44Client";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { MapContainer, TileLayer, Polygon, Tooltip as MapTooltip, useMap } from "react-leaflet";
import { Shield, Swords, Flag, ChevronDown, X, Users, Star, Lock, Unlock, Zap } from "lucide-react";
import { Button } from "@/components/ui/button";
import { toast } from "sonner";
import "leaflet/dist/leaflet.css";

// Zone data with polygon coordinates around French cities
const ZONE_DEFINITIONS = [
  { name: "Paris Centre", region: "Île-de-France", points_value: 200, lat: 48.8566, lng: 2.3522, radius: 0.04 },
  { name: "Paris Nord", region: "Île-de-France", points_value: 150, lat: 48.883, lng: 2.35, radius: 0.03 },
  { name: "Paris Est", region: "Île-de-France", points_value: 120, lat: 48.855, lng: 2.39, radius: 0.025 },
  { name: "Lyon Centre", region: "Auvergne-Rhône-Alpes", points_value: 180, lat: 45.764, lng: 4.8357, radius: 0.035 },
  { name: "Lyon Nord", region: "Auvergne-Rhône-Alpes", points_value: 100, lat: 45.795, lng: 4.83, radius: 0.025 },
  { name: "Marseille", region: "PACA", points_value: 160, lat: 43.2965, lng: 5.3698, radius: 0.04 },
  { name: "Bordeaux", region: "Nouvelle-Aquitaine", points_value: 130, lat: 44.8378, lng: -0.5792, radius: 0.03 },
  { name: "Lille", region: "Hauts-de-France", points_value: 110, lat: 50.6292, lng: 3.0573, radius: 0.03 },
  { name: "Nantes", region: "Pays de la Loire", points_value: 100, lat: 47.2184, lng: -1.5536, radius: 0.028 },
  { name: "Toulouse", region: "Occitanie", points_value: 120, lat: 43.6047, lng: 1.4442, radius: 0.03 },
  { name: "Strasbourg", region: "Grand Est", points_value: 100, lat: 48.5734, lng: 7.7521, radius: 0.025 },
  { name: "Nice", region: "PACA", points_value: 90, lat: 43.7102, lng: 7.262, radius: 0.025 },
];

function makePolygon(lat, lng, radius, sides = 6) {
  return Array.from({ length: sides }, (_, i) => {
    const angle = (i * 2 * Math.PI) / sides - Math.PI / 6;
    return [lat + radius * Math.cos(angle), lng + radius * Math.sin(angle) * 1.5];
  });
}

const ZONE_STYLES = {
  free:      { color: "#22c55e", fillColor: "#22c55e", fillOpacity: 0.12, weight: 2, dashArray: "6 4" },
  owned:     { color: "#3b82f6", fillColor: "#3b82f6", fillOpacity: 0.22, weight: 2.5, dashArray: null },
  mine:      { color: "#c8ff00", fillColor: "#c8ff00", fillOpacity: 0.18, weight: 2.5, dashArray: null },
  contested: { color: "#ef4444", fillColor: "#ef4444", fillOpacity: 0.25, weight: 3, dashArray: "4 2" },
};

function getZoneStyle(zone, myClub) {
  if (zone.is_contested) return ZONE_STYLES.contested;
  if (!zone.owner_club_id) return ZONE_STYLES.free;
  if (zone.owner_club_id === myClub?.id) return ZONE_STYLES.mine;
  return ZONE_STYLES.owned;
}

function getZoneStatus(zone, myClub) {
  if (zone.is_contested) return "contested";
  if (!zone.owner_club_id) return "free";
  if (zone.owner_club_id === myClub?.id) return "mine";
  return "owned";
}

const STATUS_LABELS = {
  free:      { label: "Zone libre",  color: "text-green-400",  bg: "bg-green-500/20",  icon: Unlock },
  mine:      { label: "Notre zone",  color: "text-[#c8ff00]",  bg: "bg-[#c8ff00]/10",  icon: Shield },
  owned:     { label: "Conquise",    color: "text-blue-400",   bg: "bg-blue-500/20",   icon: Lock },
  contested: { label: "En guerre",   color: "text-red-400",    bg: "bg-red-500/20",    icon: Swords },
};

export default function Territories() {
  const { user } = useOutletContext();
  const [selectedZone, setSelectedZone] = useState(null);
  const queryClient = useQueryClient();

  const { data: territories } = useQuery({
    queryKey: ["territories"],
    queryFn: () => base44.entities.Territory.list(),
    initialData: [],
  });

  const { data: clubs } = useQuery({
    queryKey: ["clubs"],
    queryFn: () => base44.entities.Club.list(),
    initialData: [],
  });

  const myClub = clubs.find(c => c.id === user?.club_id);

  // Merge DB territories with zone definitions
  const zones = ZONE_DEFINITIONS.map(def => {
    const db = territories.find(t => t.name === def.name) || {};
    return { ...def, ...db, polygon: makePolygon(def.lat, def.lng, def.radius) };
  });

  const initTerritories = useMutation({
    mutationFn: () => base44.entities.Territory.bulkCreate(
      ZONE_DEFINITIONS.map(({ name, region, points_value, lat, lng }) => ({ name, region, points_value, lat, lng }))
    ),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["territories"] });
      toast.success("Carte initialisée !");
    },
  });

  const claimZone = useMutation({
    mutationFn: async (zone) => {
      await base44.entities.Territory.update(zone.id, {
        owner_club_id: myClub.id,
        owner_club_name: myClub.name,
        owner_club_color: myClub.color,
      });
      await base44.entities.Club.update(myClub.id, { territories_count: (myClub.territories_count || 0) + 1 });
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["territories"] });
      queryClient.invalidateQueries({ queryKey: ["clubs"] });
      setSelectedZone(null);
      toast.success("Zone conquise !");
    },
  });

  const challengeZone = useMutation({
    mutationFn: (zone) => base44.entities.Territory.update(zone.id, {
      is_contested: true,
      challenger_club_id: myClub.id,
      challenger_club_name: myClub.name,
    }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["territories"] });
      setSelectedZone(null);
      toast.success("Défi lancé !");
    },
  });

  const freeCt  = zones.filter(z => !z.owner_club_id).length;
  const mineCt  = zones.filter(z => z.owner_club_id === myClub?.id).length;
  const warCt   = zones.filter(z => z.is_contested).length;

  return (
    <div className="relative h-[calc(100vh-56px)] lg:h-screen overflow-hidden bg-background">

      {/* ── MAP ── */}
      <MapContainer
        center={[46.6, 2.3]}
        zoom={5}
        className="w-full h-full z-0"
        zoomControl={false}
        attributionControl={false}
      >
        <TileLayer url="https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png" />

        {zones.map((zone) => {
          const style = getZoneStyle(zone, myClub);
          return (
            <Polygon
              key={zone.name}
              positions={zone.polygon}
              pathOptions={style}
              eventHandlers={{ click: () => setSelectedZone(zone) }}
            >
              <MapTooltip permanent={false} sticky>
                <span className="text-xs font-bold">{zone.name}</span>
              </MapTooltip>
            </Polygon>
          );
        })}
      </MapContainer>

      {/* ── LEGEND (top-right) ── */}
      <div className="absolute top-3 right-3 z-10 bg-card/90 backdrop-blur-md rounded-2xl border border-border p-3 space-y-1.5 shadow-xl">
        <LegendItem color="#22c55e" label="Disponible" dashed />
        <LegendItem color="#c8ff00" label="Notre zone" />
        <LegendItem color="#3b82f6" label="Conquise" />
        <LegendItem color="#ef4444" label="En guerre" />
      </div>

      {/* ── STATS BAR (top-left) ── */}
      <div className="absolute top-3 left-3 z-10 flex flex-col gap-1.5">
        <div className="bg-card/90 backdrop-blur-md rounded-2xl border border-border px-3 py-2 shadow-xl">
          <p className="text-[10px] text-muted-foreground font-medium uppercase tracking-wider mb-1">Mes territoires</p>
          <div className="flex items-center gap-3 text-xs">
            <span className="text-[#c8ff00] font-bold">{mineCt} <span className="text-muted-foreground font-normal">conquis</span></span>
            <span className="text-red-400 font-bold">{warCt} <span className="text-muted-foreground font-normal">en guerre</span></span>
            <span className="text-green-400 font-bold">{freeCt} <span className="text-muted-foreground font-normal">libres</span></span>
          </div>
        </div>
        {territories.length === 0 && (
          <button
            onClick={() => initTerritories.mutate()}
            disabled={initTerritories.isPending}
            className="bg-primary text-primary-foreground text-xs font-bold px-3 py-2 rounded-xl shadow-lg"
          >
            {initTerritories.isPending ? "Init..." : "Initialiser la carte"}
          </button>
        )}
      </div>

      {/* ── BOTTOM SHEET ── */}
      {selectedZone && (
        <ZoneBottomSheet
          zone={selectedZone}
          myClub={myClub}
          onClose={() => setSelectedZone(null)}
          onClaim={() => claimZone.mutate(selectedZone)}
          onChallenge={() => challengeZone.mutate(selectedZone)}
          claimPending={claimZone.isPending}
          challengePending={challengeZone.isPending}
        />
      )}
    </div>
  );
}

/* ── Bottom Sheet ── */
function ZoneBottomSheet({ zone, myClub, onClose, onClaim, onChallenge, claimPending, challengePending }) {
  const status = !zone.owner_club_id ? "free"
    : zone.is_contested ? "contested"
    : zone.owner_club_id === myClub?.id ? "mine"
    : "owned";

  const info = STATUS_LABELS[status];
  const StatusIcon = info.icon;

  return (
    <div className="absolute bottom-0 left-0 right-0 z-20 animate-in slide-in-from-bottom duration-300">
      {/* Backdrop */}
      <div className="absolute inset-0 -top-[200%]" onClick={onClose} />

      <div className="relative bg-card border-t border-border rounded-t-3xl shadow-2xl px-5 pt-4 pb-8"
        style={{ paddingBottom: "max(32px, calc(env(safe-area-inset-bottom) + 16px))" }}>
        {/* Handle */}
        <div className="w-10 h-1 rounded-full bg-border mx-auto mb-4" />

        {/* Close */}
        <button onClick={onClose} className="absolute top-4 right-4 p-2 text-muted-foreground">
          <X className="w-5 h-5" />
        </button>

        {/* Zone header */}
        <div className="flex items-start gap-3 mb-4">
          <div className={`w-12 h-12 rounded-2xl flex items-center justify-center shrink-0 ${info.bg}`}>
            <StatusIcon className={`w-6 h-6 ${info.color}`} />
          </div>
          <div className="flex-1">
            <h2 className="text-lg font-bold">{zone.name}</h2>
            <p className="text-xs text-muted-foreground">{zone.region}</p>
            <span className={`inline-flex items-center gap-1 text-xs font-semibold mt-1 px-2 py-0.5 rounded-full ${info.bg} ${info.color}`}>
              <StatusIcon className="w-3 h-3" />
              {info.label}
            </span>
          </div>
          <div className="text-right">
            <p className="font-display font-bold text-xl text-primary">{zone.points_value}</p>
            <p className="text-[10px] text-muted-foreground">points</p>
          </div>
        </div>

        {/* Owner info */}
        {zone.owner_club_name && (
          <div className="flex items-center gap-2 bg-secondary/50 rounded-xl px-3 py-2 mb-4">
            <div className="w-7 h-7 rounded-lg flex items-center justify-center text-sm font-bold text-white"
              style={{ backgroundColor: zone.owner_club_color || "#3b82f6" }}>
              {zone.owner_club_name[0]}
            </div>
            <div>
              <p className="text-xs font-semibold">{zone.owner_club_name}</p>
              <p className="text-[10px] text-muted-foreground">Club propriétaire</p>
            </div>
            {zone.is_contested && (
              <span className="ml-auto text-[10px] text-red-400 font-bold bg-red-500/10 px-2 py-0.5 rounded-full animate-pulse">
                DÉFI EN COURS
              </span>
            )}
          </div>
        )}

        {/* Actions */}
        {!myClub ? (
          <p className="text-center text-sm text-muted-foreground py-3">Rejoignez un club pour conquérir des zones</p>
        ) : status === "free" ? (
          <Button onClick={onClaim} disabled={claimPending} className="w-full font-display font-bold h-12 text-sm">
            <Flag className="w-4 h-4 mr-2" />
            {claimPending ? "Conquête..." : "CONQUÉRIR CETTE ZONE"}
          </Button>
        ) : status === "mine" ? (
          <div className="flex items-center justify-center gap-2 py-3">
            <Shield className="w-5 h-5 text-[#c8ff00]" />
            <span className="text-sm font-semibold text-[#c8ff00]">Zone sous votre contrôle</span>
          </div>
        ) : status === "contested" ? (
          <div className="text-center py-3">
            <p className="text-sm text-red-400 font-semibold flex items-center justify-center gap-2">
              <Swords className="w-4 h-4" /> Combat en cours pour cette zone
            </p>
          </div>
        ) : (
          <Button
            onClick={onChallenge}
            disabled={challengePending}
            variant="destructive"
            className="w-full font-display font-bold h-12 text-sm"
          >
            <Swords className="w-4 h-4 mr-2" />
            {challengePending ? "Envoi du défi..." : "ATTAQUER CETTE ZONE"}
          </Button>
        )}
      </div>
    </div>
  );
}

/* ── Legend item ── */
function LegendItem({ color, label, dashed }) {
  return (
    <div className="flex items-center gap-2">
      <div
        className="w-4 h-3 rounded-sm border"
        style={{
          borderColor: color,
          backgroundColor: color + "33",
          borderStyle: dashed ? "dashed" : "solid",
        }}
      />
      <span className="text-[10px] text-muted-foreground">{label}</span>
    </div>
  );
}