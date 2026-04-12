import { Plane, Home as HomeIcon, Utensils, PenTool, Train, Briefcase } from 'lucide-react';
import { motion } from 'motion/react';
import Header from './Header';

export default function Dashboard({ navigate }: any) {
  return (
    <div className="p-6 pt-12">
      {/* Header */}
      <Header title="首页看板" showLogo={true} />

      {/* Top Card with Capybara IP */}
      <div className="bg-gradient-to-br from-[#A8E6CF] to-[#DCEDC1] rounded-[32px] p-8 mb-8 shadow-[0_20px_40px_-10px_rgba(168,230,207,0.4)] relative overflow-hidden">
        <div className="absolute -top-10 -right-10 w-40 h-40 bg-white/20 rounded-full blur-2xl"></div>
        
        {/* Capybara Mascot & Speech Bubble */}
        <div className="absolute top-6 right-4 flex flex-col items-end z-20">
          <motion.div 
            initial={{ opacity: 0, y: 10, scale: 0.9 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            transition={{ delay: 0.2 }}
            className="bg-white/80 backdrop-blur-md px-3 py-2 rounded-2xl rounded-tr-sm shadow-sm mb-1 max-w-[130px]"
          >
            <p className="text-[#2C6957] text-[11px] font-bold leading-snug">
              早安，今天也是平静的一天呢~
            </p>
          </motion.div>
          <CapyMascot />
        </div>

        <div className="relative z-10 w-[65%]">
          <p className="text-[#2C6957]/80 text-sm font-semibold mb-2">当前支出</p>
          <h2 className="text-4xl font-extrabold text-[#2C6957] mb-8">¥ 12,840.00</h2>
          
          <div className="flex gap-4">
            <div className="flex-1 bg-white/40 rounded-2xl p-4 backdrop-blur-sm">
              <p className="text-[#2C6957]/70 text-xs font-bold mb-1">收入</p>
              <p className="text-[#2C6957] text-xl font-bold">¥ 24k</p>
            </div>
            <div className="flex-1 bg-white/40 rounded-2xl p-4 backdrop-blur-sm">
              <p className="text-[#2C6957]/70 text-xs font-bold mb-1">储蓄</p>
              <p className="text-[#2C6957] text-xl font-bold">¥ 11k</p>
            </div>
          </div>
        </div>
      </div>

      {/* Ongoing Projects */}
      <div className="mb-8">
        <div className="flex justify-between items-center mb-4">
          <h3 className="text-xl font-extrabold text-[#1A1C1C]">进行中的项目</h3>
          <button onClick={() => navigate('projects')} className="text-[#2C6956] text-sm font-bold">查看全部</button>
        </div>
        
        <div className="flex gap-4 overflow-x-auto hide-scrollbar pb-4 -mx-6 px-6 snap-x snap-mandatory scroll-pl-6">
          <ProjectCard 
            icon={<Plane size={24} className="text-[#2C6956]" />}
            iconBg="bg-[#A8E6CF]/30"
            title="新疆之旅"
            spent="8,500"
            budget="15,000"
            progress={56}
            progressColor="bg-[#2C6956]"
            onClick={() => navigate('project_detail')}
          />
          <ProjectCard 
            icon={<HomeIcon size={24} className="text-[#5F621F]" />}
            iconBg="bg-[#DCDE8D]/30"
            title="日常开销"
            spent="3,200"
            budget="4,000"
            progress={80}
            progressColor="bg-[#5F621F]"
            onClick={() => navigate('project_detail')}
          />
          <ProjectCard 
            icon={<Briefcase size={24} className="text-[#795841]" />}
            iconBg="bg-[#FDD1B4]/30"
            title="品牌重塑"
            spent="3,200"
            budget="6,800"
            progress={32}
            progressColor="bg-[#785741]"
            onClick={() => navigate('project_detail')}
          />
        </div>
      </div>

      {/* Recent Transactions */}
      <div>
        <h3 className="text-xl font-extrabold text-[#1A1C1C] mb-4">最近交易</h3>
        <div className="space-y-4">
          <TransactionItem 
            icon={<Utensils size={20} className="text-[#D97736]" />}
            iconBg="bg-[#FDD1B4]/30"
            title="海鲜餐厅"
            desc="餐饮 • 今天 12:45"
            amount="- ¥ 458.00"
            isExpense={true}
          />
          <TransactionItem 
            icon={<PenTool size={20} className="text-[#2C6956]" />}
            iconBg="bg-[#A8E6CF]/30"
            title="设计素材"
            desc="工作 • 昨天 18:20"
            amount="- ¥ 120.00"
            isExpense={true}
          />
          <TransactionItem 
            icon={<Train size={20} className="text-[#5F621F]" />}
            iconBg="bg-[#DCDE8D]/30"
            title="交通充值"
            desc="交通 • 昨天 08:30"
            amount="- ¥ 100.00"
            isExpense={true}
          />
          <TransactionItem 
            icon={<Briefcase size={20} className="text-[#2C6956]" />}
            iconBg="bg-[#A8E6CF]/30"
            title="项目结款"
            desc="收入 • 10月24日"
            amount="+ ¥ 5,000.00"
            isExpense={false}
          />
        </div>
      </div>
    </div>
  );
}

function ProjectCard({ icon, iconBg, title, spent, budget, progress, progressColor, onClick }: any) {
  return (
    <div onClick={onClick} className="w-[280px] shrink-0 snap-start bg-white rounded-3xl p-5 border border-gray-100 shadow-sm cursor-pointer hover:shadow-md transition-shadow">
      <div className="flex justify-between items-start mb-6">
        <div className={`w-12 h-12 rounded-full flex items-center justify-center ${iconBg}`}>
          {icon}
        </div>
        <span className="bg-[#FDD1B4] text-[#795841] text-[10px] font-bold px-3 py-1 rounded-full">
          进行中
        </span>
      </div>
      <h4 className="text-lg font-bold text-[#1A1C1C] mb-2">{title}</h4>
      <div className="flex justify-between text-xs text-gray-500 mb-3">
        <span>已用 ¥{spent}</span>
        <span>预算 ¥{budget}</span>
      </div>
      <div className="h-2 bg-gray-100 rounded-full overflow-hidden">
        <div className={`h-full rounded-full ${progressColor}`} style={{ width: `${progress}%` }}></div>
      </div>
    </div>
  );
}

function CapyMascot() {
  return (
    <motion.div
      animate={{ y: [0, -4, 0] }}
      transition={{ repeat: Infinity, duration: 4, ease: "easeInOut" }}
      className="relative w-20 h-20 mr-2"
    >
      <svg viewBox="0 0 100 100" className="w-full h-full drop-shadow-md">
        {/* Orange */}
        <circle cx="50" cy="22" r="10" fill="#FF9F00" />
        <path d="M50 12 Q55 6 60 12" stroke="#2C6956" strokeWidth="2.5" fill="none" strokeLinecap="round" />
        
        {/* Body/Head */}
        <rect x="25" y="32" width="50" height="55" rx="25" fill="#B08968" />
        
        {/* Ears */}
        <circle cx="25" cy="45" r="5" fill="#7F5539" />
        <circle cx="75" cy="45" r="5" fill="#7F5539" />
        
        {/* Snout */}
        <ellipse cx="50" cy="68" rx="16" ry="11" fill="#9C6644" />
        
        {/* Nose */}
        <path d="M46 64 Q50 68 54 64" stroke="#4A3022" strokeWidth="2" fill="none" strokeLinecap="round" />
        
        {/* Eyes (Relaxed/Closed) */}
        <path d="M33 52 Q36 50 39 52" stroke="#4A3022" strokeWidth="2.5" fill="none" strokeLinecap="round" />
        <path d="M61 52 Q64 50 67 52" stroke="#4A3022" strokeWidth="2.5" fill="none" strokeLinecap="round" />
        
        {/* Blush */}
        <ellipse cx="32" cy="60" rx="4" ry="2.5" fill="#FF7F50" opacity="0.6" />
        <ellipse cx="68" cy="60" rx="4" ry="2.5" fill="#FF7F50" opacity="0.6" />
      </svg>
    </motion.div>
  );
}

function TransactionItem({ icon, iconBg, title, desc, amount, isExpense }: any) {
  return (
    <div className="bg-white rounded-3xl p-4 flex items-center justify-between shadow-sm">
      <div className="flex items-center gap-4">
        <div className={`w-12 h-12 rounded-full flex items-center justify-center ${iconBg}`}>
          {icon}
        </div>
        <div>
          <h4 className="text-base font-bold text-[#1A1C1C]">{title}</h4>
          <p className="text-xs text-gray-500">{desc}</p>
        </div>
      </div>
      <span className={`text-base font-extrabold ${isExpense ? 'text-[#BA1A1A]' : 'text-[#2C6956]'}`}>
        {amount}
      </span>
    </div>
  );
}
