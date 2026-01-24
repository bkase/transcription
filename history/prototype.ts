import React, { useState, useEffect, useRef } from 'react';
import { Mic, Pause, StopCircle, ChevronLeft, MoreHorizontal, Calendar, Clock, Share, Play } from 'lucide-react';

/**
 * BRAND GUIDELINES: VAPOR
 * * Colors:
 * - Cloud: #FFFFFF
 * - Mist: #F7FAFC
 * - Haze: #EDF2F7
 * - Text Primary: #2D3748
 * - Text Secondary: #718096
 * - Accent Sky: #A0C4E8
 * - Accent Lavender: #C9B8D8
 * - Recording: #E88B8B (60% opacity)
 * * Motion:
 * - Slow, drifting, blurring.
 * - No snapping.
 */

// --- Type Definitions ---
type ViewState = 'home' | 'recording' | 'session';

interface TranscriptSegment {
  id: string;
  speaker: 'user' | 'guest';
  text: string;
  timestamp: string;
  isFinal?: boolean;
}

interface SessionData {
  id: string;
  title: string;
  date: string;     // Display date (e.g. "9:41 AM")
  groupDate: string; // Grouping key (e.g. "Today", "Yesterday")
  duration: string;
  preview: string;
  segments: TranscriptSegment[];
}

// --- Mock Data ---
const MOCK_SESSIONS: SessionData[] = [
  {
    id: '1',
    title: 'Architecture Review',
    groupDate: 'Today',
    date: '9:41 AM',
    duration: '42:10',
    preview: 'So we\'re looking at the Vapor direction...',
    segments: [
      { id: '1', speaker: 'user', text: "So we're looking at the Vapor direction.", timestamp: "00:12" },
      { id: '2', speaker: 'guest', text: "Exactly. It needs to feel like breath on glass. Nothing solid until it's saved.", timestamp: "00:18" },
      { id: '3', speaker: 'user', text: "I love that metaphor. The UI should barely be there. Just the words floating in space.", timestamp: "00:24" },
      { id: '4', speaker: 'guest', text: "Right, and when we look at the transcript, it shouldn't feel like a messaging app. It should feel like a script. A record.", timestamp: "00:30" },
      { id: '5', speaker: 'user', text: "Agreed. Let's tighten up the spacing. No bubbles, just text.", timestamp: "00:35" },
    ]
  },
  {
    id: '2',
    title: 'Morning Reflection',
    groupDate: 'Today',
    date: '7:30 AM',
    duration: '15:00',
    preview: 'The light in the studio was particularly interesting this morning...',
    segments: []
  },
  {
    id: '3',
    title: 'Product Strategy',
    groupDate: 'Yesterday',
    date: '4:20 PM',
    duration: '1:12:00',
    preview: 'If we pivot to a local-first model, the database sync becomes...',
    segments: []
  },
  {
    id: '4',
    title: 'Coffee with Sarah',
    groupDate: 'Yesterday',
    date: '10:00 AM',
    duration: '28:45',
    preview: 'Have you seen the new exhibit at the MoMA? It reminds me of...',
    segments: []
  },
  {
    id: '5',
    title: 'Design Critique',
    groupDate: 'January 12',
    date: '2:15 PM',
    duration: '45:20',
    preview: 'The typography is too heavy. We need to go thinner, lighter...',
    segments: []
  },
  {
    id: '6',
    title: 'Idea Walk',
    groupDate: 'December 20, 2025',
    date: '11:00 AM',
    duration: '12:05',
    preview: 'Note to self: explore the concept of digital ephemeralism...',
    segments: []
  }
];

// --- Live Transcript Simulation Data (Turns) ---
const LIVE_TURNS = [
  { speaker: 'user', text: "Conversations are like breath—ephemeral unless captured." },
  { speaker: 'guest', text: "The Vapor brand treats speech as something delicate." },
  { speaker: 'user', text: "It preserves without intruding. It's barely there." },
  { speaker: 'guest', text: "Exactly. A whisper-quiet presence." }
];

export default function VaporApp() {
  const [view, setView] = useState<ViewState>('home');
  const [activeSession, setActiveSession] = useState<SessionData | null>(null);
  
  // Custom navigation handler
  const goHome = () => setView('home');
  const goRecord = () => setView('recording');
  const goSession = (session: SessionData) => {
    setActiveSession(session);
    setView('session');
  };

  return (
    <div className="font-sans antialiased text-[#2D3748] bg-[#F7FAFC] min-h-screen w-full selection:bg-[#A0C4E8] selection:text-white overflow-hidden relative">
      {/* Global Styles for Vapor Animations */}
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=Inter:wght@100;200;300;400;500&display=swap');
        
        body {
          font-family: 'Inter', -apple-system, sans-serif;
        }

        .vapor-text-primary { color: #2D3748; }
        .vapor-text-secondary { color: #718096; }
        
        @keyframes vaporAppear {
          0% { opacity: 0; transform: translateY(4px) scale(0.99); filter: blur(4px); }
          100% { opacity: 1; transform: translateY(0) scale(1); filter: blur(0px); }
        }
        
        @keyframes vaporBreathe {
          0% { transform: scale(1); opacity: 0.5; }
          50% { transform: scale(1.05); opacity: 0.8; }
          100% { transform: scale(1); opacity: 0.5; }
        }

        @keyframes vaporDrift {
          0% { transform: translateY(0px); }
          50% { transform: translateY(-4px); }
          100% { transform: translateY(0px); }
        }

        .animate-vapor-appear {
          animation: vaporAppear 0.5s cubic-bezier(0.16, 1, 0.3, 1) forwards;
        }

        .animate-vapor-breathe {
          animation: vaporBreathe 3s cubic-bezier(0.45, 0, 0.55, 1) infinite;
        }

        .animate-vapor-drift {
          animation: vaporDrift 4s ease-in-out infinite;
        }
        
        /* Hide scrollbar for cleaner look */
        .no-scrollbar::-webkit-scrollbar {
          display: none;
        }
        .no-scrollbar {
          -ms-overflow-style: none;
          scrollbar-width: none;
        }
      `}</style>

      {/* Main Content Switcher */}
      <div className="max-w-md mx-auto h-screen bg-[#F7FAFC] relative shadow-2xl overflow-hidden flex flex-col">
        
        {/* Dynamic Header */}
        <header className="pt-14 pb-4 px-6 flex justify-between items-center z-20 animate-vapor-appear bg-gradient-to-b from-[#F7FAFC] to-transparent">
          {view === 'home' ? (
            <div className="flex flex-col">
              <span className="text-xs font-light tracking-[0.2em] text-[#A0AEC0] uppercase mb-1">Archive</span>
              <h1 className="text-3xl font-thin tracking-tight text-[#2D3748]">Timeline</h1>
            </div>
          ) : (
             <button 
               onClick={goHome}
               className="p-2 -ml-2 rounded-full hover:bg-[#EDF2F7] transition-colors duration-300 group flex items-center gap-1"
             >
               <ChevronLeft className="w-5 h-5 text-[#718096] stroke-[1.5px]" />
               <span className="text-sm font-light text-[#718096] group-hover:text-[#2D3748]">Back</span>
             </button>
          )}
          
          <button className="p-1 rounded-full hover:bg-[#EDF2F7] transition-colors duration-300">
             <div className="w-8 h-8 rounded-full border border-[#E2E8F0] overflow-hidden">
                <img src="https://api.dicebear.com/7.x/avataaars/svg?seed=Felix" alt="Profile" className="opacity-80 grayscale hover:grayscale-0 transition-all duration-500" />
             </div>
          </button>
        </header>

        {/* View Container */}
        <main className="flex-1 relative flex flex-col overflow-hidden">
          {view === 'home' && <HomeView onRecord={goRecord} onSelectSession={goSession} />}
          {view === 'recording' && <RecordingView onStop={goHome} />}
          {view === 'session' && activeSession && <SessionView session={activeSession} />}
        </main>

        {/* Floating Action Button (Only on Home) */}
        {view === 'home' && (
           <div className="absolute bottom-10 left-0 right-0 flex justify-center z-30 animate-vapor-appear pointer-events-none">
             <button 
               onClick={goRecord}
               className="pointer-events-auto group relative w-20 h-20 rounded-full bg-white shadow-[0_8px_30px_rgba(0,0,0,0.08)] flex items-center justify-center transition-transform duration-500 hover:scale-105 active:scale-95"
             >
               <div className="absolute inset-0 rounded-full border border-[#E2E8F0] opacity-50 group-hover:opacity-100 transition-opacity duration-300"></div>
               <div className="w-3 h-3 rounded-full bg-[#E88B8B] opacity-60 group-hover:opacity-80 transition-opacity"></div>
             </button>
           </div>
        )}
      </div>
    </div>
  );
}

// --- Sub-Views ---

function HomeView({ onRecord, onSelectSession }: { onRecord: () => void, onSelectSession: (s: SessionData) => void }) {
  // Group sessions by date
  const groupedSessions = MOCK_SESSIONS.reduce((groups, session) => {
    const date = session.groupDate;
    if (!groups[date]) {
      groups[date] = [];
    }
    groups[date].push(session);
    return groups;
  }, {} as Record<string, SessionData[]>);

  const groupKeys = Object.keys(groupedSessions);

  return (
    <div className="px-6 h-full overflow-y-auto no-scrollbar pb-32 pt-2 space-y-8 animate-vapor-appear">
      
      {/* Search / Filter Placeholder */}
      <div className="relative mb-2">
        <div className="h-10 w-full bg-white/50 backdrop-blur-sm rounded-xl border border-[#EDF2F7] flex items-center px-4 transition-all focus-within:bg-white focus-within:shadow-sm">
          <span className="text-[#A0AEC0] font-light text-sm">Search transcripts...</span>
        </div>
      </div>

      {groupKeys.map((groupDate, groupIdx) => (
        <div key={groupDate} className="relative">
          {/* Date Header - Stickyish feel */}
          <div className="sticky top-0 z-10 bg-[#F7FAFC]/95 backdrop-blur-sm py-2 mb-2">
            <h3 className="text-xs font-medium uppercase tracking-widest text-[#A0AEC0] pl-1">
              {groupDate}
            </h3>
          </div>

          <div className="space-y-4">
            {groupedSessions[groupDate].map((session, idx) => (
              <div 
                key={session.id}
                onClick={() => onSelectSession(session)}
                className="relative px-4 py-5 cursor-pointer group transition-all duration-700 ease-out hover:bg-white hover:rounded-2xl hover:shadow-[0_12px_32px_rgba(160,196,232,0.1)] border border-transparent hover:border-white/50 hover:-translate-y-0.5"
                style={{ animationDelay: `${(groupIdx * 100) + (idx * 50)}ms` }}
              >
                {/* Clean Layout: No lines, just floating text */}
                
                <div className="flex justify-between items-baseline mb-2">
                  <h3 className="text-lg font-light text-[#2D3748] tracking-tight group-hover:text-[#4A5568] transition-colors">{session.title}</h3>
                  <span className="font-mono text-[10px] text-[#A0AEC0] opacity-60 group-hover:opacity-100 transition-opacity">{session.date}</span>
                </div>
                
                <p className="text-[#718096] font-light text-sm leading-relaxed line-clamp-2 opacity-80">
                  {session.preview}
                </p>
                
                {/* Metadata floats up on hover */}
                <div className="flex items-center gap-2 mt-4 opacity-0 group-hover:opacity-100 transition-all duration-500 transform translate-y-2 group-hover:translate-y-0">
                   <span className="text-[10px] font-mono text-[#718096] bg-[#F7FAFC] px-2 py-1 rounded-md">{session.duration}</span>
                   {session.segments.length > 0 && <span className="text-[10px] font-mono text-[#A0C4E8] bg-[#A0C4E8]/10 px-2 py-1 rounded-md">Transcribed</span>}
                </div>
              </div>
            ))}
          </div>
        </div>
      ))}
    </div>
  );
}

function RecordingView({ onStop }: { onStop: () => void }) {
  const [segments, setSegments] = useState<TranscriptSegment[]>([]);
  const [seconds, setSeconds] = useState(0);
  const bottomRef = useRef<HTMLDivElement>(null);

  // Simulate Timer
  useEffect(() => {
    const timer = setInterval(() => setSeconds(s => s + 1), 1000);
    return () => clearInterval(timer);
  }, []);

  // Simulate Live "Turn-taking" Transcription
  useEffect(() => {
    let turnIndex = 0;
    
    // Initial delay before starting
    const startDelay = setTimeout(() => {
        const interval = setInterval(() => {
          if (turnIndex < LIVE_TURNS.length) {
            const turn = LIVE_TURNS[turnIndex];
            const newSegment: TranscriptSegment = {
                id: `live-${Date.now()}`,
                speaker: turn.speaker as 'user' | 'guest',
                text: turn.text,
                timestamp: formatTime(seconds + (turnIndex * 3)), // Approximate time
                isFinal: false
            };
            
            setSegments(prev => [...prev, newSegment]);
            turnIndex++;
            
            // Auto scroll
            if(bottomRef.current) {
                bottomRef.current.scrollIntoView({ behavior: 'smooth' });
            }
          }
        }, 2500); // New turn every 2.5 seconds
        return () => clearInterval(interval);
    }, 500);

    return () => clearTimeout(startDelay);
  }, []);

  const formatTime = (totalSeconds: number) => {
    const m = Math.floor(totalSeconds / 60).toString().padStart(2, '0');
    const s = (totalSeconds % 60).toString().padStart(2, '0');
    return `${m}:${s}`;
  };

  return (
    <div className="h-full flex flex-col relative overflow-hidden bg-[#F7FAFC]">
      
      {/* Background Ambience (Subtler for readability) */}
      <div className="absolute top-0 left-0 w-full h-full pointer-events-none opacity-30">
         <div className="absolute top-[-10%] left-[-20%] w-[500px] h-[500px] bg-[#E8F1F8] rounded-full blur-[80px] animate-vapor-drift"></div>
         <div className="absolute bottom-[-10%] right-[-20%] w-[400px] h-[400px] bg-[#F3EBF7] rounded-full blur-[80px] animate-vapor-drift" style={{ animationDelay: '2s' }}></div>
      </div>

      {/* Recording Header */}
      <div className="px-6 py-4 flex justify-between items-center z-20 border-b border-[#E2E8F0]/50 bg-[#F7FAFC]/80 backdrop-blur-sm">
        <div className="flex items-center gap-3">
            <div className="w-2 h-2 rounded-full bg-[#E88B8B] animate-pulse"></div>
            <span className="text-sm font-light text-[#E88B8B] tracking-wide uppercase">Recording</span>
        </div>
        <div className="font-mono font-light text-xl text-[#2D3748] tracking-widest opacity-80">
          {formatTime(seconds)}
        </div>
      </div>

      {/* Live Transcript List */}
      <div className="flex-1 w-full overflow-y-auto px-6 py-6 z-10 no-scrollbar">
        <div className="space-y-6">
            {segments.length === 0 && (
                <div className="flex h-full items-center justify-center pt-20 opacity-40">
                    <p className="font-light italic text-[#A0AEC0] animate-vapor-breathe">Listening...</p>
                </div>
            )}
            
            {segments.map((seg, i) => (
                <div 
                    key={seg.id} 
                    className="animate-vapor-appear flex flex-col gap-1"
                >
                    <div className="flex items-baseline gap-3">
                        <span 
                            className={`text-[10px] font-bold tracking-[0.1em] uppercase 
                            ${seg.speaker === 'user' ? 'text-[#A0C4E8]' : 'text-[#C9B8D8]'}
                            `}
                        >
                            {seg.speaker === 'user' ? 'You' : 'Guest'}
                        </span>
                        <span className="text-[10px] font-mono text-[#CBD5E0]">{formatTime(seconds - (segments.length - i) * 2)}</span>
                    </div>
                    <p className="text-[16px] font-light leading-[1.6] text-[#2D3748]">
                        {seg.text}
                    </p>
                </div>
            ))}
            <div ref={bottomRef} className="h-20" /> {/* Spacer for bottom controls */}
        </div>
      </div>

      {/* Controls */}
      <div className="absolute bottom-0 left-0 right-0 h-32 bg-gradient-to-t from-[#F7FAFC] via-[#F7FAFC] to-transparent z-20 flex items-center justify-center gap-12 pb-4">
        <button className="p-4 rounded-full text-[#A0C4E8] hover:bg-white hover:shadow-lg transition-all duration-500 transform hover:scale-105">
           <Pause className="w-6 h-6 stroke-[1px]" />
        </button>

        {/* Breathing Record Button (Stop) - INCREASED SIZE */}
        <button 
          onClick={onStop}
          className="relative w-28 h-28 rounded-full flex items-center justify-center group"
        >
          {/* Breathing Ring */}
          <div className="absolute inset-0 rounded-full bg-[#E88B8B] animate-vapor-breathe"></div>
          {/* Core */}
          <div className="relative w-28 h-28 bg-white rounded-full shadow-[0_4px_24px_rgba(232,139,139,0.2)] flex items-center justify-center transition-transform duration-500 group-hover:scale-105 border border-[#FFF5F5]">
             <div className="w-8 h-8 rounded bg-[#E88B8B] opacity-80"></div>
          </div>
        </button>

        <button className="p-4 rounded-full text-[#A0AEC0] hover:bg-white hover:shadow-lg transition-all duration-500 transform hover:scale-105">
           <MoreHorizontal className="w-6 h-6 stroke-[1px]" />
        </button>
      </div>
    </div>
  );
}

function SessionView({ session }: { session: SessionData }) {
  return (
    <div className="h-full flex flex-col bg-[#F7FAFC] animate-vapor-appear">
      
      {/* Session Header (Compact) */}
      <div className="px-6 py-4 border-b border-[#E2E8F0]/50 flex justify-between items-start bg-white/50 backdrop-blur-sm z-10">
        <div>
            <h2 className="text-xl font-normal text-[#2D3748] tracking-tight mb-1">{session.title}</h2>
            <div className="flex items-center gap-3 text-xs font-light text-[#718096]">
            <span>{session.date}</span>
            <span className="w-1 h-1 rounded-full bg-[#CBD5E0]"></span>
            <span>{session.duration}</span>
            </div>
        </div>
        <div className="flex gap-2">
             <button className="p-2 text-[#A0AEC0] hover:text-[#2D3748] transition-colors"><Share className="w-4 h-4" /></button>
             <button className="p-2 text-[#A0AEC0] hover:text-[#2D3748] transition-colors"><MoreHorizontal className="w-4 h-4" /></button>
        </div>
      </div>

      {/* Transcript Scroll Area - TIGHT PODCAST STYLE */}
      <div className="flex-1 overflow-y-auto px-6 pt-6 pb-32 space-y-6 no-scrollbar">
        
        {session.segments.map((seg, i) => (
          <div 
            key={seg.id} 
            className="flex flex-col gap-1 animate-vapor-appear"
            style={{ animationDelay: `${i * 50}ms` }}
          >
            {/* Header: Speaker + Time */}
            <div className="flex items-baseline gap-3">
              <span 
                className={`text-[10px] font-bold tracking-[0.1em] uppercase 
                   ${seg.speaker === 'user' ? 'text-[#A0C4E8]' : 'text-[#C9B8D8]'}
                `}
              >
                {seg.speaker === 'user' ? 'You' : 'Guest'}
              </span>
              <span className="text-[10px] font-mono text-[#CBD5E0] opacity-0 hover:opacity-100 transition-opacity cursor-default">{seg.timestamp}</span>
            </div>
            
            {/* Body Text */}
            <div className="text-[16px] font-light leading-[1.6] text-[#2D3748] tracking-normal">
              {seg.text}
            </div>
          </div>
        ))}
        
        <div className="h-12 border-t border-[#E2E8F0]/30 mt-8 flex items-center justify-center">
            <span className="text-[10px] uppercase tracking-widest text-[#CBD5E0]">End of Session</span>
        </div>
      </div>

      {/* Floating Player Control - LIQUID GLASS STYLE */}
      <div className="absolute bottom-8 left-6 right-6 z-30 animate-vapor-appear">
         <div className="bg-white/60 backdrop-blur-2xl backdrop-saturate-150 border border-white/40 ring-1 ring-white/30 p-4 rounded-3xl shadow-[0_8px_32px_0_rgba(31,38,135,0.07)] flex items-center gap-4">
             <button className="w-10 h-10 rounded-full bg-[#2D3748] flex items-center justify-center text-white shadow-lg hover:scale-105 transition-transform">
                <Play className="w-4 h-4 ml-0.5 fill-current" />
             </button>
             
             <div className="flex-1 flex flex-col justify-center gap-1">
                 <span className="text-xs font-medium text-[#2D3748]">Playing Audio</span>
                 {/* Progress Bar */}
                 <div className="w-full h-1 bg-[#EDF2F7]/50 rounded-full overflow-hidden">
                    <div className="w-1/3 h-full bg-[#A0C4E8] rounded-full"></div>
                 </div>
             </div>
             
             <span className="font-mono text-[10px] text-[#718096]">12:40</span>
         </div>
      </div>
    </div>
  );
}
