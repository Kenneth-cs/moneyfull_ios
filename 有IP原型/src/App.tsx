/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import React, { useState } from 'react';
import { Home, LayoutGrid, BarChart2, User, Plus } from 'lucide-react';
import { cn } from './lib/utils';
import Dashboard from './components/Dashboard';
import Projects from './components/Projects';
import Analytics from './components/Analytics';
import Profile from './components/Profile';
import AddRecord from './components/AddRecord';
import ProjectDetail from './components/ProjectDetail';
import NewProject from './components/NewProject';

export default function App() {
  const [activeTab, setActiveTab] = useState('home');
  const [subView, setSubView] = useState<string | null>(null);
  const [isAddOpen, setIsAddOpen] = useState(false);

  const navigate = (view: string) => {
    if (['home', 'projects', 'analytics', 'profile'].includes(view)) {
      setActiveTab(view);
      setSubView(null);
    } else {
      setSubView(view);
    }
  };

  return (
    <div className="flex justify-center w-full min-h-screen bg-gray-100">
      <div className="relative w-full max-w-md bg-[#F9F9F9] min-h-screen shadow-2xl overflow-hidden flex flex-col">
        {/* Main Content Area */}
        <div className="flex-1 overflow-y-auto pb-24 hide-scrollbar">
          {!subView && activeTab === 'home' && <Dashboard navigate={navigate} />}
          {!subView && activeTab === 'projects' && <Projects navigate={navigate} />}
          {!subView && activeTab === 'analytics' && <Analytics navigate={navigate} />}
          {!subView && activeTab === 'profile' && <Profile navigate={navigate} />}
          
          {subView === 'project_detail' && <ProjectDetail navigate={navigate} />}
          {subView === 'new_project' && <NewProject navigate={navigate} />}
        </div>

        {/* Bottom Navigation - Hidden when in subviews */}
        {!subView && (
          <div className="absolute bottom-6 left-4 right-4 bg-white/80 backdrop-blur-md rounded-full shadow-[0_20px_40px_-5px_rgba(0,0,0,0.1)] px-2 py-3 flex justify-between items-center z-40">
            <NavItem 
              icon={<Home size={24} />} 
              label="首页" 
              isActive={activeTab === 'home'} 
              onClick={() => navigate('home')} 
            />
            <NavItem 
              icon={<LayoutGrid size={24} />} 
              label="项目" 
              isActive={activeTab === 'projects'} 
              onClick={() => navigate('projects')} 
            />
            
            {/* Center Add Button */}
            <div className="relative -top-8 flex justify-center items-center">
              <button 
                onClick={() => setIsAddOpen(true)}
                className="w-16 h-16 bg-[#A8E6CF] rounded-full flex items-center justify-center text-[#2C6957] shadow-[0_10px_20px_rgba(168,230,207,0.5)] hover:scale-105 transition-transform"
              >
                <Plus size={32} strokeWidth={2.5} />
              </button>
            </div>

            <NavItem 
              icon={<BarChart2 size={24} />} 
              label="统计" 
              isActive={activeTab === 'analytics'} 
              onClick={() => navigate('analytics')} 
            />
            <NavItem 
              icon={<User size={24} />} 
              label="我的" 
              isActive={activeTab === 'profile'} 
              onClick={() => navigate('profile')} 
            />
          </div>
        )}

        {/* Add Record Modal */}
        {isAddOpen && <AddRecord onClose={() => setIsAddOpen(false)} />}
      </div>
    </div>
  );
}

function NavItem({ icon, label, isActive, onClick }: { icon: React.ReactNode, label: string, isActive: boolean, onClick: () => void }) {
  return (
    <button 
      onClick={onClick}
      className={cn(
        "flex flex-col items-center justify-center w-16 h-12 rounded-full transition-colors",
        isActive ? "text-[#1A1C1C]" : "text-gray-400"
      )}
    >
      <div className={cn("mb-1", isActive && "bg-[#A8E6CF]/30 p-1.5 rounded-full")}>
        {icon}
      </div>
      <span className={cn("text-[10px] font-medium", isActive ? "text-[#1A1C1C]" : "text-gray-400")}>
        {label}
      </span>
    </button>
  );
}
