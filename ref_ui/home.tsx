import { Bell, Crown, Users, TrendingUp, Plus, Map, Play, Eye } from "lucide-react";
import { Link } from "react-router";

export function HomePage() {
  const recentMatches = [
    { team1: "Flèches...", score: "3 - 1", team2: "Boulev...", isWin: true },
  ];

  const upcomingTournament = {
    name: "Bataille de Bastille",
    date: "Dans 2 jours",
    clubs: "8/16",
  };

  const teamMembers = [
    { name: "Alex", role: "Cap", avatar: "👤" },
    { name: "Sarah", role: "", avatar: "👤" },
    { name: "Marc", role: "", avatar: "👤" },
  ];

  return (
    <div className="min-h-screen bg-[#0f0f14] text-white">
      {/* Header */}
      <div className="flex items-center justify-between p-4 border-b border-gray-800">
        <div className="flex items-center gap-3">
          <div className="w-12 h-12 rounded-full bg-gradient-to-br from-blue-500 to-purple-600 flex items-center justify-center relative">
            <span className="text-sm">👤</span>
            <div className="absolute -bottom-0.5 -right-0.5 w-4 h-4 bg-green-500 rounded-full border-2 border-[#0f0f14]"></div>
          </div>
          <div>
            <h2 className="text-base font-bold">Les Flèches de Fer</h2>
            <p className="text-xs text-gray-400">Paris 11ème</p>
          </div>
        </div>
        <button className="w-10 h-10 flex items-center justify-center rounded-full bg-[#1a1a24] border border-gray-700">
          <Bell className="w-5 h-5" />
        </button>
      </div>

      <div className="p-4 space-y-4">
        {/* Match à valider */}
        <div className="bg-gradient-to-r from-red-900/20 to-red-800/10 border border-red-800/30 rounded-xl p-4">
          <div className="flex items-start justify-between">
            <div className="flex items-center gap-2">
              <div className="w-8 h-8 flex items-center justify-center bg-red-600 rounded-full">
                ⚠️
              </div>
              <div>
                <h3 className="text-sm font-bold">Match à valider</h3>
                <p className="text-xs text-red-300">vs Les Requins (il y a 2h)</p>
              </div>
            </div>
            <button className="px-4 py-2 bg-red-600 hover:bg-red-700 rounded-lg text-xs font-bold">
              Valider
            </button>
          </div>
        </div>

        {/* Stats Cards */}
        <div className="grid grid-cols-2 gap-4">
          <div className="bg-[#1a1a24] border border-gray-800 rounded-xl p-4">
            <div className="flex items-center gap-2 mb-2">
              <div className="w-8 h-8 flex items-center justify-center bg-blue-600/20 rounded-lg">
                <Users className="w-4 h-4 text-blue-400" />
              </div>
              <span className="text-xs text-gray-400">Territoires contrôlés</span>
            </div>
            <div className="flex items-end justify-between">
              <div className="text-2xl font-bold">12</div>
              <div className="flex items-center gap-1 text-green-500 text-xs">
                <TrendingUp className="w-3 h-3" />
                <span>+2</span>
              </div>
            </div>
          </div>

          <div className="bg-[#1a1a24] border border-gray-800 rounded-xl p-4">
            <div className="flex items-center gap-2 mb-2">
              <div className="w-8 h-8 flex items-center justify-center bg-yellow-600/20 rounded-lg">
                <Crown className="w-4 h-4 text-yellow-400" />
              </div>
              <span className="text-xs text-gray-400">Rang de conquête</span>
            </div>
            <div className="text-2xl font-bold">850</div>
          </div>
        </div>

        {/* Forme Récente */}
        <div className="bg-[#1a1a24] border border-gray-800 rounded-xl p-4">
          <div className="flex items-center justify-between mb-4">
            <h3 className="font-bold">Forme Récente</h3>
            <Link to="/stats" className="text-xs text-blue-400">Voir l'historique</Link>
          </div>
          
          <div className="flex items-center gap-2 mb-4">
            {['V', 'V', 'D', 'V', '-'].map((result, i) => (
              <div 
                key={i}
                className={`w-8 h-8 flex items-center justify-center rounded font-bold text-xs ${
                  result === 'V' ? 'bg-green-600' : 
                  result === 'D' ? 'bg-red-600' : 
                  'bg-gray-700'
                }`}
              >
                {result}
              </div>
            ))}
            <span className="ml-2 text-green-400 font-bold">75% Victoires</span>
          </div>

          <div className="flex items-center gap-3 p-3 bg-[#0f0f14] rounded-lg">
            <div className="flex items-center gap-2">
              <div className="w-8 h-8 rounded-full bg-gradient-to-br from-blue-500 to-purple-600" />
              <span className="text-xs font-bold">Flèches...</span>
            </div>
            <div className="flex items-center gap-2">
              <span className="text-green-400 font-bold">3 - 1</span>
            </div>
            <div className="flex items-center gap-2">
              <span className="text-xs">Boulev...</span>
            </div>
            <button className="ml-auto w-6 h-6 flex items-center justify-center rounded bg-gray-700">
              <Eye className="w-4 h-4" />
            </button>
          </div>
        </div>

        {/* Actions Rapides */}
        <div className="bg-[#1a1a24] border border-gray-800 rounded-xl p-4">
          <h3 className="font-bold mb-4">Actions Rapides</h3>
          <div className="grid grid-cols-3 gap-3">
            <Link 
              to="/tournaments"
              className="flex flex-col items-center justify-center gap-2 p-4 bg-[#0f0f14] rounded-xl hover:bg-[#1a1a24] transition-colors"
            >
              <div className="w-10 h-10 flex items-center justify-center bg-gray-700 rounded-full">
                <Plus className="w-5 h-5" />
              </div>
              <span className="text-xs text-center">Créer Tournoi</span>
            </Link>
            
            <button className="flex flex-col items-center justify-center gap-2 p-4 bg-[#0f0f14] rounded-xl hover:bg-[#1a1a24] transition-colors">
              <div className="w-10 h-10 flex items-center justify-center bg-gray-700 rounded-full">
                <Map className="w-5 h-5" />
              </div>
              <span className="text-xs text-center">Ouvrir Carte</span>
            </button>
            
            <Link
              to="/match/1"
              className="flex flex-col items-center justify-center gap-2 p-4 bg-[#6366f1] rounded-xl hover:bg-[#5558e3] transition-colors"
            >
              <div className="w-10 h-10 flex items-center justify-center bg-white/20 rounded-full">
                <Play className="w-5 h-5" />
              </div>
              <span className="text-xs text-center">Lancer Match</span>
            </Link>
          </div>
        </div>

        {/* Prochains Tournois */}
        <div className="bg-[#1a1a24] border border-gray-800 rounded-xl p-4">
          <div className="flex items-center justify-between mb-4">
            <h3 className="font-bold">Prochains Tournois</h3>
            <Link to="/tournaments" className="text-xs text-blue-400">Voir tout</Link>
          </div>
          
          <Link 
            to="/tournaments/1"
            className="flex items-center gap-3 p-3 bg-[#0f0f14] rounded-lg border border-blue-500/20 hover:border-blue-500/40 transition-colors"
          >
            <div className="flex-1">
              <div className="flex items-center gap-2 mb-1">
                <span className="px-2 py-1 bg-blue-600/20 text-blue-400 text-xs rounded">Local</span>
                <span className="text-xs text-gray-400">⏱ {upcomingTournament.date}</span>
              </div>
              <h4 className="font-bold text-sm mb-1">{upcomingTournament.name}</h4>
              <p className="text-xs text-gray-400">{upcomingTournament.clubs} Clubs inscrits</p>
            </div>
            <button className="px-4 py-2 bg-[#6366f1] hover:bg-[#5558e3] rounded-lg text-xs font-bold whitespace-nowrap">
              S'inscrire
            </button>
          </Link>
        </div>

        {/* Effectif Actif */}
        <div className="bg-[#1a1a24] border border-gray-800 rounded-xl p-4">
          <h3 className="font-bold mb-4">Effectif Actif</h3>
          <div className="flex items-center gap-3">
            {teamMembers.map((member, i) => (
              <div key={i} className="flex flex-col items-center gap-1">
                <div className="w-14 h-14 rounded-full bg-gradient-to-br from-blue-500 to-purple-600 flex items-center justify-center text-xl relative">
                  {member.avatar}
                  {member.role === "Cap" && (
                    <div className="absolute -bottom-1 w-5 h-5 bg-yellow-500 rounded-full flex items-center justify-center">
                      <Crown className="w-3 h-3 text-black" />
                    </div>
                  )}
                </div>
                <span className="text-xs">{member.name} {member.role && `(${member.role})`}</span>
              </div>
            ))}
            <button className="flex flex-col items-center gap-1">
              <div className="w-14 h-14 rounded-full border-2 border-dashed border-gray-600 flex items-center justify-center">
                <Plus className="w-6 h-6 text-gray-400" />
              </div>
              <span className="text-xs text-gray-400">Inviter</span>
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
