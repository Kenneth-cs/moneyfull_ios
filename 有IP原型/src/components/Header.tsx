import { Bell, ChevronLeft } from 'lucide-react';

export default function Header({ title, onBack, showBell = true, showLogo = false }: any) {
  return (
    <div className="flex justify-between items-center mb-8 relative">
      <div className="w-10 flex justify-start z-10">
        {onBack && (
          <button onClick={onBack} className="p-2 -ml-2">
            <ChevronLeft size={28} className="text-[#1A1C1C]" />
          </button>
        )}
      </div>
      
      <div className="flex items-center gap-2 absolute inset-0 justify-center pointer-events-none">
        {showLogo && (
          <svg width="28" height="28" viewBox="0 0 28 28" fill="none" xmlns="http://www.w3.org/2000/svg">
            <circle cx="18" cy="10" r="4.5" stroke="#A8E6CF" strokeWidth="2"/>
            <circle cx="10" cy="16" r="3" stroke="#A8E6CF" strokeWidth="2"/>
            <circle cx="15" cy="20" r="1.5" stroke="#A8E6CF" strokeWidth="2"/>
          </svg>
        )}
        <h1 className="text-xl font-extrabold text-[#1A1C1C] tracking-wide">{title}</h1>
      </div>

      <div className="w-10 flex justify-end z-10">
        {showBell && (
          <button className="p-2 -mr-2 pointer-events-auto">
            <Bell size={24} className="text-gray-600" />
          </button>
        )}
      </div>
    </div>
  );
}
